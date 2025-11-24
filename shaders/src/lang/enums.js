const legacyEnums = {};
const mutableEnums = legacyEnums;
let frozenEnums = null;

function cloneEnumTree(source, mergeEnumsFn) {
  const clone = {};
  if (mergeEnumsFn) {
      mergeEnumsFn(clone, source);
  } else {
      // Simple shallow merge if no function provided
      Object.assign(clone, source);
  }
  return clone;
}

function deepFreezeEnumTree(node) {
  if (!node || typeof node !== 'object' || Object.isFrozen(node)) { return node; }
  Object.freeze(node);
  Object.values(node).forEach((child) => {
    if (child && typeof child === 'object') {
      deepFreezeEnumTree(child);
    }
  });
  return node;
}

function rebuildFrozenEnums(mergeEnumsFn) {
  const clone = cloneEnumTree(mutableEnums, mergeEnumsFn);
  frozenEnums = deepFreezeEnumTree(clone);
}

export async function mergeIntoEnums(source, mergeEnumsFn) {
  if (!source || typeof source !== 'object') { return frozenEnums; }
  if (mergeEnumsFn) {
      mergeEnumsFn(mutableEnums, source);
  } else {
      Object.assign(mutableEnums, source);
  }
  rebuildFrozenEnums(mergeEnumsFn);
  return frozenEnums;
}

// Initialize with empty enums
rebuildFrozenEnums();

export { frozenEnums as default };
