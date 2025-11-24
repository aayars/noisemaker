const canonicalRegistry = new Map()
const moduleNamespaceOwnership = new Map()
const featureFlagOverrides = new Map()

let namespacedExportsEnabled = false

function normalizeName(value) {
    if (typeof value !== 'string') { return null }
    const trimmed = value.trim()
    return trimmed ? trimmed : null
}

export { normalizeName as normalizeNamespaceName }

function makeCanonicalKey(namespaceId, canonicalName) {
    return `${namespaceId}::${canonicalName}`
}

function createNamespaceRecord({ namespaceId, canonicalName, featureFlag }, moduleName) {
    return {
        namespace: namespaceId,
        canonicalName,
        featureFlag: featureFlag || null,
        module: moduleName || null
    }
}

function snapshotRecord(record) {
    if (!record) { return null }
    return {
        namespace: record.namespace,
        canonicalName: record.canonicalName,
        namespacedName: `${record.namespace}.${record.canonicalName}`,
        module: record.module || null,
        featureFlag: record.featureFlag || null,
        exportsEnabled: isRecordEnabled(record)
    }
}

function normalizeNamespaceDescriptor(entry) {
    if (!entry || typeof entry !== 'object') { return null }
    const namespaceId = normalizeName(entry.namespaceId || entry.id || entry.namespace)
    const canonicalName = normalizeName(entry.canonicalName || entry.name || entry.target)
    if (!namespaceId || !canonicalName) { return null }
    const featureFlag = normalizeName(entry.featureFlag || entry.flag) || null
    return {
        namespaceId,
        canonicalName,
        featureFlag
    }
}

export function unregisterNamespaceTargets(moduleName) {
    const normalizedModule = normalizeName(moduleName)
    if (!normalizedModule) { return }
    const owned = moduleNamespaceOwnership.get(normalizedModule)
    if (!owned) { return }
    owned.forEach((canonicalKey) => {
        const record = canonicalRegistry.get(canonicalKey)
        if (record) {
            canonicalRegistry.delete(canonicalKey)
        }
    })
    moduleNamespaceOwnership.delete(normalizedModule)
}

export function registerNamespaceTargets(moduleName, entries = []) {
    const normalizedModule = normalizeName(moduleName)
    if (normalizedModule) {
        unregisterNamespaceTargets(normalizedModule)
    }
    if (!Array.isArray(entries) || entries.length === 0) {
        return []
    }
    const ownedKeys = new Set()
    const normalizedEntries = []
    entries.forEach((entry) => {
        const normalized = normalizeNamespaceDescriptor(entry)
        if (!normalized) { return }
        normalizedEntries.push(normalized)
    })
    if (normalizedEntries.length === 0) {
        if (normalizedModule) {
            moduleNamespaceOwnership.delete(normalizedModule)
        }
        return []
    }
    normalizedEntries.forEach((entry) => {
        const canonicalKey = makeCanonicalKey(entry.namespaceId, entry.canonicalName)
        let record = canonicalRegistry.get(canonicalKey)
        if (!record) {
            record = createNamespaceRecord(entry, normalizedModule)
            canonicalRegistry.set(canonicalKey, record)
        } else {
            record.namespace = entry.namespaceId
            record.canonicalName = entry.canonicalName
            record.featureFlag = entry.featureFlag || null
            record.module = normalizedModule || record.module || null
        }
        ownedKeys.add(canonicalKey)
    })
    if (normalizedModule) {
        if (ownedKeys.size > 0) {
            moduleNamespaceOwnership.set(normalizedModule, ownedKeys)
        } else {
            moduleNamespaceOwnership.delete(normalizedModule)
        }
    }
    return normalizedEntries
}

function isRecordEnabled(record) {
    if (!namespacedExportsEnabled) { return false }
    if (!record) { return false }
    const featureFlag = record.featureFlag
    if (!featureFlag) { return true }
    return featureFlagOverrides.get(featureFlag) === true
}

export function buildNamespaceExportMap({ includeDisabled = false } = {}) {
    if (!includeDisabled && !namespacedExportsEnabled) {
        return Object.freeze({})
    }
    const result = {}
    canonicalRegistry.forEach((record) => {
        if (!includeDisabled && !isRecordEnabled(record)) { return }
        const canonicalName = record.canonicalName
        if (!canonicalName) { return }
        result[canonicalName] = `${record.namespace}.${record.canonicalName}`
    })
    return Object.freeze(result)
}

export function enableNamespacedExports(enabled = true) {
    namespacedExportsEnabled = !!enabled
}

export function areNamespacedExportsEnabled() {
    return namespacedExportsEnabled
}

export function setNamespaceFeatureFlag(flagName, enabled) {
    const normalized = normalizeName(flagName)
    if (!normalized) { return }
    if (enabled) {
        featureFlagOverrides.set(normalized, true)
    } else {
        featureFlagOverrides.delete(normalized)
    }
}

export function getNamespaceMetadata(namespaceId, canonicalName) {
    const normalizedNamespace = normalizeName(namespaceId)
    const normalizedCanonical = normalizeName(canonicalName)
    if (!normalizedNamespace || !normalizedCanonical) { return null }
    const record = canonicalRegistry.get(makeCanonicalKey(normalizedNamespace, normalizedCanonical))
    return snapshotRecord(record)
}

export function getCanonicalNamespaceRecord(namespaceId, canonicalName) {
    const normalizedNamespace = normalizeName(namespaceId)
    const normalizedCanonical = normalizeName(canonicalName)
    if (!normalizedNamespace || !normalizedCanonical) { return null }
    const record = canonicalRegistry.get(makeCanonicalKey(normalizedNamespace, normalizedCanonical))
    return snapshotRecord(record)
}

export function resetNamespaceRegistryForTesting() {
    canonicalRegistry.clear()
    moduleNamespaceOwnership.clear()
    featureFlagOverrides.clear()
    namespacedExportsEnabled = false
}

export default Object.freeze({
    registerNamespaceTargets,
    unregisterNamespaceTargets,
    buildNamespaceExportMap,
    enableNamespacedExports,
    areNamespacedExportsEnabled,
    setNamespaceFeatureFlag,
    getNamespaceMetadata,
    getCanonicalNamespaceRecord,
    normalizeNamespaceName: normalizeName,
    resetNamespaceRegistryForTesting
})
