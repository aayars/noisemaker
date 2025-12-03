/**
 * Demo UI Module for Noisemaker Shader Demo
 * 
 * Handles all UI-specific logic: controls, dialogs, selectors, DSL editing.
 * Works in conjunction with CanvasRenderer for the rendering pipeline.
 * 
 * @example
 * import { DemoUI } from './lib/demo-ui.js';
 * import { CanvasRenderer } from '../../shaders/src/renderer/canvas.js';
 * 
 * const renderer = new CanvasRenderer({ canvas, ... });
 * const ui = new DemoUI(renderer, {
 *     effectSelect: document.getElementById('effect-select'),
 *     dslEditor: document.getElementById('dsl-editor'),
 *     controlsContainer: document.getElementById('effect-controls-container'),
 *     statusEl: document.getElementById('status'),
 *     ...
 * });
 */

import { compile, unparse } from '../../../shaders/src/lang/index.js';
import { 
    CanvasRenderer, 
    getEffect, 
    cloneParamValue, 
    isStarterEffect, 
    hasTexSurfaceParam, 
    is3dGenerator, 
    is3dProcessor,
    isValidIdentifier,
    sanitizeEnumName
} from '../../../shaders/src/renderer/canvas.js';

/**
 * Format enum name for DSL output - quote if not a valid identifier
 * @param {string} name - Name to format
 * @returns {string} Formatted name
 */
export function formatEnumName(name) {
    const sanitized = sanitizeEnumName(name);
    if (sanitized !== null) {
        return sanitized;
    }
    // Can't be an identifier - quote it as a string
    return `"${name.replace(/"/g, '\\"')}"`;
}

/**
 * Format a value for DSL output
 * @param {*} value - Value to format
 * @param {object} spec - Parameter spec
 * @param {object} enums - Enum registry
 * @returns {string} Formatted value
 */
export function formatValue(value, spec, enums = {}) {
    const type = spec?.type || (typeof spec === 'string' ? spec : 'float');
    
    // If spec has inline choices, look up the enum name
    if (spec?.choices && typeof value === 'number') {
        for (const [name, val] of Object.entries(spec.choices)) {
            if (name.endsWith(':')) continue; // skip group labels
            if (val === value) {
                return formatEnumName(name);
            }
        }
    }
    
    // If spec has enum (global enum reference), look up the name
    if (spec?.enum && typeof value === 'number') {
        const enumPath = spec.enum;
        const parts = enumPath.split('.');
        let node = enums;
        for (const part of parts) {
            if (node && node[part]) {
                node = node[part];
            } else {
                node = null;
                break;
            }
        }
        if (node && typeof node === 'object') {
            for (const [name, val] of Object.entries(node)) {
                const numVal = (val && typeof val === 'object' && 'value' in val) ? val.value : val;
                if (numVal === value) {
                    return `${enumPath}.${name}`;
                }
            }
        }
    }
    
    if (type === 'boolean' || type === 'button') {
        return value ? 'true' : 'false';
    }
    if (type === 'surface') {
        if (typeof value !== 'string' || value.length === 0) {
            return 'src(o0)';
        }
        if (value.includes('(')) {
            return value;
        }
        return `src(${value})`;
    }
    if (type === 'member') {
        return value;
    }
    if (type === 'vec4' && Array.isArray(value)) {
        const toHex = (n) => Math.round(n * 255).toString(16).padStart(2, '0');
        return `#${toHex(value[0])}${toHex(value[1])}${toHex(value[2])}${toHex(value[3])}`;
    }
    if (type === 'vec3' && Array.isArray(value)) {
        return `vec3(${value.join(', ')})`;
    }
    if (type === 'vec2' && Array.isArray(value)) {
        return `vec2(${value.join(', ')})`;
    }
    if (type === 'palette' || type === 'string' || type === 'text') {
        return `"${value}"`;
    }
    // float, int
    return value;
}

/**
 * Extract effect names from DSL text without compiling (for lazy loading)
 * @param {string} dsl - DSL source
 * @param {object} manifest - Shader manifest
 * @returns {Array} Array of { effectId, namespace, name }
 */
export function extractEffectNamesFromDsl(dsl, manifest) {
    const effects = [];
    if (!dsl || typeof dsl !== 'string') return effects;

    const lines = dsl.split('\n');
    let searchNamespaces = [];
    
    for (const line of lines) {
        const trimmed = line.trim();
        
        if (trimmed.startsWith('search ')) {
            searchNamespaces = trimmed.slice(7).split(',').map(s => s.trim());
            continue;
        }
        
        if (!trimmed || trimmed.startsWith('//')) continue;
        
        const callPattern = /\b([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?)\s*\(/g;
        let match;
        
        while ((match = callPattern.exec(trimmed)) !== null) {
            const fullName = match[1];
            let namespace = null;
            let name = fullName;
            
            if (fullName.includes('.')) {
                const parts = fullName.split('.');
                namespace = parts[0];
                name = parts[1];
            }
            
            const builtins = ['src', 'out', 'vec2', 'vec3', 'vec4'];
            if (builtins.includes(name)) continue;
            
            if (!namespace && searchNamespaces.length > 0) {
                for (const ns of searchNamespaces) {
                    const testId = `${ns}/${name}`;
                    if (manifest[testId]) {
                        namespace = ns;
                        break;
                    }
                }
            }
            
            if (!namespace) {
                for (const ns of ['classicBasics', 'classicNoisemaker', 'classicNoisedeck', 'filter', 'mixer', 'synth', 'stateful']) {
                    const testId = `${ns}/${name}`;
                    if (manifest[testId]) {
                        namespace = ns;
                        break;
                    }
                }
            }
            
            if (namespace) {
                const effectId = `${namespace}/${name}`;
                if (!effects.find(e => e.effectId === effectId)) {
                    effects.push({ effectId, namespace, name });
                }
            }
        }
    }

    return effects;
}

/**
 * Extract effects from compiled DSL
 * @param {string} dsl - DSL source
 * @returns {Array} Array of effect info objects
 */
export function extractEffectsFromDsl(dsl) {
    const effects = [];
    if (!dsl || typeof dsl !== 'string') return effects;

    try {
        const result = compile(dsl);
        if (!result || !result.plans) return effects;

        let globalStepIndex = 0;
        for (const plan of result.plans) {
            if (!plan.chain) continue;
            for (const step of plan.chain) {
                const fullOpName = step.op;
                const namespace = step.namespace?.namespace || step.namespace?.resolved || null;
                
                let shortName = fullOpName;
                if (fullOpName.includes('.')) {
                    shortName = fullOpName.split('.').pop();
                }
                
                effects.push({
                    effectKey: fullOpName,
                    namespace,
                    name: shortName,
                    fullName: fullOpName,
                    args: step.args || {},
                    stepIndex: globalStepIndex,
                    temp: step.temp
                });
                globalStepIndex++;
            }
        }
    } catch (err) {
        console.warn('Failed to parse DSL for effect extraction:', err);
    }

    return effects;
}

/**
 * Get backend from URL query parameter
 * @returns {string|null} Backend name or null
 */
export function getBackendFromURL() {
    const params = new URLSearchParams(window.location.search);
    return params.get('backend');
}

/**
 * Get effect from URL query parameter
 * @returns {string|null} Effect path (namespace/name) or null
 */
export function getEffectFromURL() {
    const params = new URLSearchParams(window.location.search);
    const effectParam = params.get('effect');
    
    if (!effectParam) return null;
    
    const parts = effectParam.split('.');
    if (parts.length === 2) {
        return `${parts[0]}/${parts[1]}`;
    }
    
    return null;
}

/**
 * DemoUI class - handles all UI interactions for the shader demo
 */
export class DemoUI {
    /**
     * Create a new DemoUI instance
     * @param {CanvasRenderer} renderer - The canvas renderer instance
     * @param {object} options - UI element references
     * @param {HTMLSelectElement} options.effectSelect - Effect selector element
     * @param {HTMLTextAreaElement} options.dslEditor - DSL editor element
     * @param {HTMLElement} options.controlsContainer - Effect controls container
     * @param {HTMLElement} options.statusEl - Status message element
     * @param {HTMLElement} [options.fpsCounterEl] - FPS counter display element
     * @param {HTMLDialogElement} [options.loadingDialog] - Loading dialog element
     * @param {HTMLElement} [options.loadingDialogTitle] - Loading dialog title
     * @param {HTMLElement} [options.loadingDialogStatus] - Loading dialog status
     * @param {HTMLElement} [options.loadingDialogProgress] - Loading dialog progress bar
     */
    constructor(renderer, options = {}) {
        this._renderer = renderer;
        
        // DOM elements
        this._effectSelect = options.effectSelect;
        this._dslEditor = options.dslEditor;
        this._controlsContainer = options.controlsContainer;
        this._statusEl = options.statusEl;
        this._fpsCounterEl = options.fpsCounterEl;
        this._loadingDialog = options.loadingDialog;
        this._loadingDialogTitle = options.loadingDialogTitle;
        this._loadingDialogStatus = options.loadingDialogStatus;
        this._loadingDialogProgress = options.loadingDialogProgress;
        
        // State
        this._parameterValues = {};
        this._effectParameterValues = {}; // Map: step_N -> {param: value}
        this._parsedDslStructure = [];
        this._allEffects = [];
        
        // Loading state
        this._loadingState = {
            queue: [],
            completed: 0,
            total: 0
        };
        
        // Bind the formatValue function with enums context
        this._boundFormatValue = (value, spec) => formatValue(value, spec, this._renderer.enums);
    }
    
    // =========================================================================
    // Getters
    // =========================================================================
    
    /** @returns {object} Current parameter values */
    get parameterValues() {
        return this._parameterValues;
    }
    
    /** @returns {object} Effect parameter values by step */
    get effectParameterValues() {
        return this._effectParameterValues;
    }
    
    /** @returns {Array} All effect placeholders */
    get allEffects() {
        return this._allEffects;
    }
    
    // =========================================================================
    // Status Display
    // =========================================================================
    
    /**
     * Show a status message
     * @param {string} message - Message to display
     * @param {string} [type='info'] - Message type (info, success, error)
     */
    showStatus(message, type = 'info') {
        if (!this._statusEl) return;
        
        this._statusEl.textContent = message;
        this._statusEl.className = `status ${type}`;
        this._statusEl.style.display = 'block';
        setTimeout(() => {
            this._statusEl.style.display = 'none';
        }, 3000);
    }
    
    /**
     * Update FPS counter display
     * @param {number} fps - Current FPS
     */
    updateFPSCounter(fps) {
        if (this._fpsCounterEl) {
            this._fpsCounterEl.textContent = `${fps} fps`;
        }
    }
    
    // =========================================================================
    // Loading Dialog
    // =========================================================================
    
    /**
     * Show the loading dialog
     * @param {string} [title='loading effect...'] - Dialog title
     */
    showLoadingDialog(title = 'loading effect...') {
        if (!this._loadingDialog) return;
        
        if (this._loadingDialogTitle) {
            this._loadingDialogTitle.textContent = title;
        }
        if (this._loadingDialogStatus) {
            this._loadingDialogStatus.textContent = 'preparing...';
        }
        if (this._loadingDialogProgress) {
            this._loadingDialogProgress.style.width = '0%';
        }
        
        this._loadingState = { queue: [], completed: 0, total: 0 };
        this._loadingDialog.showModal();
    }
    
    /**
     * Hide the loading dialog
     */
    hideLoadingDialog() {
        if (this._loadingDialog) {
            this._loadingDialog.close();
        }
    }
    
    /**
     * Update loading status text
     * @param {string} status - Status message
     */
    updateLoadingStatus(status) {
        if (this._loadingDialogStatus) {
            this._loadingDialogStatus.textContent = status;
        }
    }
    
    /**
     * Update loading progress
     */
    updateLoadingProgress() {
        if (!this._loadingDialogProgress) return;
        
        const progress = this._loadingState.total > 0 
            ? (this._loadingState.completed / this._loadingState.total) * 100 
            : 0;
        this._loadingDialogProgress.style.width = `${progress}%`;
    }
    
    /**
     * Add item to loading queue
     * @param {string} id - Item ID
     * @param {string} label - Item label
     */
    addToLoadingQueue(id, label) {
        this._loadingState.queue.push({ id, label, status: 'pending' });
        this._loadingState.total++;
    }
    
    /**
     * Update loading queue item status
     * @param {string} id - Item ID
     * @param {string} status - New status
     */
    updateLoadingQueueItem(id, status) {
        const item = this._loadingState.queue.find(i => i.id === id);
        if (item) {
            item.status = status;
            if (status === 'done' || status === 'error') {
                this._loadingState.completed++;
            }
            this.updateLoadingProgress();
        }
    }
    
    // =========================================================================
    // Effect Selector
    // =========================================================================
    
    /**
     * Populate the effect selector dropdown
     * @param {Array} effects - Array of effect objects
     */
    populateEffectSelector(effects) {
        if (!this._effectSelect) return;
        
        this._allEffects = effects;
        this._effectSelect.innerHTML = '';
        
        const grouped = {};
        effects.forEach(effect => {
            if (!grouped[effect.namespace]) {
                grouped[effect.namespace] = [];
            }
            grouped[effect.namespace].push(effect);
        });

        const sortedNamespaces = Object.keys(grouped).sort((a, b) => {
            const aIsClassic = a.startsWith('classic');
            const bIsClassic = b.startsWith('classic');
            if (aIsClassic && !bIsClassic) return 1;
            if (!aIsClassic && bIsClassic) return -1;
            return a.localeCompare(b);
        });

        sortedNamespaces.forEach(namespace => {
            const effectList = grouped[namespace];
            const optgroup = document.createElement('optgroup');
            optgroup.label = namespace;
            
            effectList.sort((a, b) => a.name.localeCompare(b.name)).forEach(effect => {
                const option = document.createElement('option');
                option.value = `${namespace}/${effect.name}`;
                option.textContent = effect.name;
                optgroup.appendChild(option);
            });
            
            this._effectSelect.appendChild(optgroup);
        });
    }
    
    /**
     * Set the selected effect in the dropdown
     * @param {string} effectPath - Effect path (namespace/name)
     */
    setSelectedEffect(effectPath) {
        if (!this._effectSelect) return;
        
        for (let i = 0; i < this._effectSelect.options.length; i++) {
            if (this._effectSelect.options[i].value === effectPath) {
                this._effectSelect.selectedIndex = i;
                break;
            }
        }
    }
    
    // =========================================================================
    // DSL Handling
    // =========================================================================
    
    /**
     * Get current DSL from editor
     * @returns {string} DSL content
     */
    getDsl() {
        return this._dslEditor ? this._dslEditor.value.trim() : '';
    }
    
    /**
     * Set DSL in editor
     * @param {string} dsl - DSL content
     */
    setDsl(dsl) {
        if (this._dslEditor) {
            this._dslEditor.value = dsl || '';
        }
    }
    
    /**
     * Build DSL source from an effect and parameter values
     * @param {object} effect - Effect object
     * @returns {string} Generated DSL
     */
    buildDslSource(effect) {
        if (!effect || !effect.instance) {
            return '';
        }

        // Build search directive - always include synth for noise() starter
        let searchNs = effect.namespace;
        if (effect.namespace === 'classicNoisemaker') {
            searchNs = 'classicNoisemaker, classicBasics, synth';
        } else if (['filter', 'mixer', 'stateful'].includes(effect.namespace)) {
            searchNs = `${effect.namespace}, synth`;
        }
        const searchDirective = searchNs ? `search ${searchNs}\n` : '';
        const funcName = effect.instance.func;

        const starter = isStarterEffect(effect);
        const hasTex = hasTexSurfaceParam(effect);

        // 3D volume generators
        if (is3dGenerator(effect)) {
            const params = [];
            if (effect.instance.globals) {
                for (const [key, spec] of Object.entries(effect.instance.globals)) {
                    const value = this._parameterValues[key];
                    if (value === undefined || value === null) continue;
                    params.push(`${key}: ${this._boundFormatValue(value, spec)}`);
                }
            }
            const paramString = params.join(', ');
            return `search vol\n${funcName}(${paramString}).render3d().write(o0)`;
        }

        if (starter) {
            const params = [];
            if (effect.instance.globals) {
                for (const [key, spec] of Object.entries(effect.instance.globals)) {
                    const value = this._parameterValues[key];
                    if (value === undefined || value === null) continue;
                    params.push(`${key}: ${this._boundFormatValue(value, spec)}`);
                }
            }
            const paramString = params.join(', ');
            
            if (hasTex) {
                const sourceSurface = 'o1';
                const outputSurface = 'o0';
                const paramsWithTex = paramString 
                    ? `tex: src(${sourceSurface}), ${paramString}` 
                    : `tex: src(${sourceSurface})`;
                return `${searchDirective}noise(seed: 1, ridges: true).write(${sourceSurface})\n${funcName}(${paramsWithTex}).write(${outputSurface})`;
            }
            return `${searchDirective}${funcName}(${paramString}).write(o0)`;
        } else if (hasTex) {
            const params = [`tex: src(o1)`];
            if (effect.instance.globals) {
                for (const [key, spec] of Object.entries(effect.instance.globals)) {
                    if (key === 'tex' && spec.type === 'surface') continue;
                    const value = this._parameterValues[key];
                    if (value === undefined || value === null) continue;
                    params.push(`${key}: ${this._boundFormatValue(value, spec)}`);
                }
            }
            const paramString = params.join(', ');
            return `${searchDirective}noise(seed: 1, ridges: true).write(o1)\nnoise(seed: 2, ridges: true).${funcName}(${paramString}).write(o0)`;
        } else if (is3dProcessor(effect)) {
            const params = [];
            let consumerVolumeSize = 32;
            if (effect.instance.globals) {
                for (const [key, spec] of Object.entries(effect.instance.globals)) {
                    const value = this._parameterValues[key];
                    if (value === undefined || value === null) continue;
                    if (key === 'volumeSize') consumerVolumeSize = value;
                    params.push(`${key}: ${this._boundFormatValue(value, spec)}`);
                }
            }
            const paramString = params.join(', ');
            const generatorDsl = `noise3d(volumeSize: x${consumerVolumeSize})`;
            if (paramString) {
                return `search vol\n${generatorDsl}.${funcName}(${paramString}).render3d().write(o0)`;
            }
            return `search vol\n${generatorDsl}.${funcName}().render3d().write(o0)`;
        } else {
            const params = [];
            if (effect.instance.globals) {
                for (const [key, spec] of Object.entries(effect.instance.globals)) {
                    const value = this._parameterValues[key];
                    if (value === undefined || value === null) continue;
                    params.push(`${key}: ${this._boundFormatValue(value, spec)}`);
                }
            }
            const paramString = params.join(', ');
            return `${searchDirective}noise(seed: 1, ridges: true).${funcName}(${paramString}).write(o0)`;
        }
    }
    
    /**
     * Regenerate DSL from effect parameter values
     * @returns {string|null} Regenerated DSL or null on error
     */
    regenerateDslFromEffectParams() {
        const currentDslText = this.getDsl();
        if (!currentDslText) return null;
        
        try {
            const compiled = compile(currentDslText);
            if (!compiled || !compiled.plans) return null;
            
            const overrides = {};
            for (const [key, params] of Object.entries(this._effectParameterValues)) {
                const match = key.match(/^step_(\d+)$/);
                if (match) {
                    const stepIndex = parseInt(match[1], 10);
                    overrides[stepIndex] = params;
                }
            }
            
            const searchMatch = currentDslText.match(/^search\s+(\S.*?)$/m);
            if (searchMatch) {
                compiled.searchNamespaces = searchMatch[1].split(/\s*,\s*/);
            }
            
            const getEffectDefCallback = (effectName, namespace) => {
                let def = getEffect(effectName);
                if (def) return def;
                
                if (namespace) {
                    def = getEffect(`${namespace}/${effectName}`) || 
                          getEffect(`${namespace}.${effectName}`);
                    if (def) return def;
                }
                
                return null;
            };
            
            return unparse(compiled, overrides, {
                customFormatter: this._boundFormatValue,
                getEffectDef: getEffectDefCallback
            });
        } catch (err) {
            console.warn('Failed to regenerate DSL:', err);
            return null;
        }
    }
    
    // =========================================================================
    // Effect Controls
    // =========================================================================
    
    /**
     * Create effect controls from DSL
     * @param {string} dsl - DSL source
     */
    createEffectControlsFromDsl(dsl) {
        if (!this._controlsContainer) return;
        
        this._controlsContainer.innerHTML = '';
        this._effectParameterValues = {};

        const effects = extractEffectsFromDsl(dsl);
        this._parsedDslStructure = effects;
        if (effects.length === 0) return;

        for (const effectInfo of effects) {
            let effectDef = getEffect(effectInfo.effectKey);
            if (!effectDef && effectInfo.namespace) {
                effectDef = getEffect(`${effectInfo.namespace}.${effectInfo.name}`);
            }
            if (!effectDef) {
                effectDef = getEffect(effectInfo.name);
            }

            if (!effectDef || !effectDef.globals) continue;

            const moduleDiv = document.createElement('div');
            moduleDiv.className = 'shader-module';
            moduleDiv.dataset.stepIndex = effectInfo.stepIndex;
            moduleDiv.dataset.effectName = effectInfo.name;

            const titleDiv = document.createElement('div');
            titleDiv.className = 'module-title';
            titleDiv.textContent = effectInfo.namespace 
                ? `${effectInfo.namespace}.${effectInfo.name}` 
                : effectInfo.name;
            titleDiv.addEventListener('click', () => {
                moduleDiv.classList.toggle('collapsed');
            });
            moduleDiv.appendChild(titleDiv);

            const contentDiv = document.createElement('div');
            contentDiv.className = 'module-content';

            const controlsDiv = document.createElement('div');
            controlsDiv.id = `controls-${effectInfo.stepIndex}`;
            controlsDiv.style.cssText = 'background: transparent; border: 1px solid color-mix(in srgb, var(--accent3) 15%, transparent 85%); border-radius: var(--ui-corner-radius); padding: 0.75rem; display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem;';

            const effectKey = `step_${effectInfo.stepIndex}`;
            this._effectParameterValues[effectKey] = {};

            for (const [key, spec] of Object.entries(effectDef.globals)) {
                if (spec.ui && spec.ui.control === false) continue;
                if (spec.type === 'surface') continue;

                const controlGroup = this._createControlGroup(
                    key, 
                    spec, 
                    effectInfo, 
                    effectKey
                );
                if (controlGroup) {
                    controlsDiv.appendChild(controlGroup);
                }
            }

            contentDiv.appendChild(controlsDiv);
            moduleDiv.appendChild(contentDiv);
            this._controlsContainer.appendChild(moduleDiv);
        }
    }
    
    /**
     * Create a control group for a parameter
     * @private
     */
    _createControlGroup(key, spec, effectInfo, effectKey) {
        const controlGroup = document.createElement('div');
        controlGroup.className = 'control-group';

        const header = document.createElement('div');
        header.className = 'control-header';
        
        const label = document.createElement('label');
        label.className = 'control-label';
        label.textContent = spec.ui?.label || key;
        header.appendChild(label);
        
        controlGroup.appendChild(header);

        // Get value from DSL args or use default
        let value = effectInfo.args[key];
        if (value === undefined) {
            value = cloneParamValue(spec.default);
        }
        this._effectParameterValues[effectKey][key] = value;

        // Create control based on type
        if (spec.type === 'boolean') {
            this._createBooleanControl(controlGroup, key, value, effectKey);
        } else if (spec.choices) {
            this._createChoicesControl(controlGroup, key, spec, value, effectKey);
        } else if (spec.enum && spec.type === 'int') {
            this._createEnumIntControl(controlGroup, key, spec, value, effectKey);
        } else if (spec.type === 'member') {
            this._createMemberControl(controlGroup, key, spec, value, effectKey);
        } else if (spec.type === 'float' || spec.type === 'int') {
            this._createSliderControl(controlGroup, header, key, spec, value, effectKey);
        } else if (spec.type === 'vec4') {
            this._createColorControl(controlGroup, key, value, effectKey);
        }

        return controlGroup;
    }
    
    /** @private */
    _createBooleanControl(container, key, value, effectKey) {
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.checked = !!value;
        checkbox.addEventListener('change', (e) => {
            this._effectParameterValues[effectKey][key] = e.target.checked;
            this._onControlChange();
        });
        container.appendChild(checkbox);
    }
    
    /** @private */
    _createChoicesControl(container, key, spec, value, effectKey) {
        const select = document.createElement('select');
        select.className = 'control-select';

        let selectedValue = null;
        let optionIndex = 0;

        Object.entries(spec.choices).forEach(([name, val]) => {
            if (name.endsWith(':')) return;

            const option = document.createElement('option');
            option.value = String(optionIndex);
            option.textContent = name;
            option.dataset.paramValue = JSON.stringify(val);
            if ((value === null && val === null) || value === val) {
                option.selected = true;
                selectedValue = option.value;
            }
            select.appendChild(option);
            optionIndex += 1;
        });

        if (selectedValue !== null) {
            select.value = selectedValue;
        }

        select.addEventListener('change', (e) => {
            const target = e.target;
            const option = target.options[target.selectedIndex];
            const raw = option?.dataset?.paramValue;

            let parsedValue = null;
            if (raw !== undefined) {
                try {
                    parsedValue = JSON.parse(raw);
                } catch (_err) {
                    parsedValue = raw;
                }
            }

            this._effectParameterValues[effectKey][key] = parsedValue;
            this._onControlChange();
        });

        container.appendChild(select);
    }
    
    /** @private */
    _createEnumIntControl(container, key, spec, value, effectKey) {
        const enumPath = spec.enum;
        const parts = enumPath.split('.');
        let node = this._renderer.enums;
        for (const part of parts) {
            if (node && node[part]) {
                node = node[part];
            } else {
                node = null;
                break;
            }
        }

        if (node && typeof node === 'object') {
            const select = document.createElement('select');
            select.className = 'control-select';
            
            Object.entries(node).forEach(([name, val]) => {
                const option = document.createElement('option');
                const numVal = (val && typeof val === 'object' && 'value' in val) ? val.value : val;
                option.value = numVal;
                option.textContent = name;
                option.selected = value === numVal;
                select.appendChild(option);
            });
            
            select.addEventListener('change', (e) => {
                this._effectParameterValues[effectKey][key] = parseInt(e.target.value, 10);
                this._onControlChange();
            });
            container.appendChild(select);
        } else {
            // Fallback to slider
            const slider = document.createElement('input');
            slider.type = 'range';
            slider.min = spec.min || 0;
            slider.max = spec.max || 10;
            slider.value = value;
            slider.addEventListener('change', (e) => {
                this._effectParameterValues[effectKey][key] = parseInt(e.target.value, 10);
                this._onControlChange();
            });
            container.appendChild(slider);
        }
    }
    
    /** @private */
    _createMemberControl(container, key, spec, value, effectKey) {
        let enumPath = spec.enum || spec.enumPath;
        if (!enumPath && typeof spec.default === 'string') {
            const parts = spec.default.split('.');
            if (parts.length > 1) {
                enumPath = parts.slice(0, -1).join('.');
            }
        }

        if (enumPath) {
            const parts = enumPath.split('.');
            let node = this._renderer.enums;
            for (const part of parts) {
                if (node && node[part]) {
                    node = node[part];
                } else {
                    node = null;
                    break;
                }
            }

            if (node) {
                const select = document.createElement('select');
                select.className = 'control-select';
                Object.keys(node).forEach(k => {
                    const option = document.createElement('option');
                    const fullPath = `${enumPath}.${k}`;
                    option.value = fullPath;
                    option.textContent = k;
                    option.selected = fullPath === value;
                    select.appendChild(option);
                });
                
                select.addEventListener('change', (e) => {
                    this._effectParameterValues[effectKey][key] = e.target.value;
                    this._onControlChange();
                });
                container.appendChild(select);
            }
        }
    }
    
    /** @private */
    _createSliderControl(container, header, key, spec, value, effectKey) {
        const valueDisplay = document.createElement('span');
        valueDisplay.className = 'control-value';
        const formatVal = (v, isInt) => isInt ? v : Number(v).toFixed(2);
        valueDisplay.textContent = value !== null ? formatVal(value, spec.type === 'int') : '';
        header.appendChild(valueDisplay);

        const slider = document.createElement('input');
        slider.className = 'control-slider';
        slider.type = 'range';
        slider.min = spec.min !== undefined ? spec.min : 0;
        slider.max = spec.max !== undefined ? spec.max : 100;
        slider.step = spec.step !== undefined ? spec.step : (spec.type === 'int' ? 1 : 0.01);
        slider.value = value !== null ? value : slider.min;

        slider.addEventListener('input', (e) => {
            const numVal = spec.type === 'int' ? parseInt(e.target.value) : parseFloat(e.target.value);
            valueDisplay.textContent = formatVal(numVal, spec.type === 'int');
            this._effectParameterValues[effectKey][key] = numVal;
            this._applyEffectParameterValues();
        });
        
        slider.addEventListener('change', () => {
            this._onControlChange();
        });

        container.appendChild(slider);
    }
    
    /** @private */
    _createColorControl(container, key, value, effectKey) {
        const colorInput = document.createElement('input');
        colorInput.type = 'color';
        
        if (Array.isArray(value)) {
            const toHex = (n) => Math.round(n * 255).toString(16).padStart(2, '0');
            colorInput.value = `#${toHex(value[0])}${toHex(value[1])}${toHex(value[2])}`;
        }

        colorInput.addEventListener('input', (e) => {
            const hex = e.target.value;
            const r = parseInt(hex.slice(1, 3), 16) / 255;
            const g = parseInt(hex.slice(3, 5), 16) / 255;
            const b = parseInt(hex.slice(5, 7), 16) / 255;
            const a = Array.isArray(this._effectParameterValues[effectKey][key]) 
                ? this._effectParameterValues[effectKey][key][3] 
                : 1;
            this._effectParameterValues[effectKey][key] = [r, g, b, a];
            this._onControlChange();
        });
        container.appendChild(colorInput);
    }
    
    /** @private Called when a control value changes */
    _onControlChange() {
        this._applyEffectParameterValues();
        this._updateDslFromEffectParams();
    }
    
    /**
     * Apply effect parameter values to the running pipeline
     * @private
     */
    _applyEffectParameterValues() {
        const pipeline = this._renderer.pipeline;
        if (!pipeline || !pipeline.graph || !pipeline.graph.passes) return;

        let zoomChanged = false;

        for (const [effectKey, params] of Object.entries(this._effectParameterValues)) {
            const match = effectKey.match(/^step_(\d+)$/);
            if (!match) continue;
            const stepIndex = parseInt(match[1], 10);
            
            const stepPasses = pipeline.graph.passes.filter(pass => {
                if (!pass.id) return false;
                const passMatch = pass.id.match(/^node_(\d+)_pass_/);
                return passMatch && parseInt(passMatch[1], 10) === stepIndex;
            });
            
            if (stepPasses.length === 0) continue;
            
            const firstPass = stepPasses[0];
            const passFunc = firstPass.effectFunc || firstPass.effectKey;
            const passNamespace = firstPass.effectNamespace;
            let effectDef = null;
            if (passFunc) {
                if (passNamespace) {
                    effectDef = getEffect(`${passNamespace}.${passFunc}`) || getEffect(`${passNamespace}/${passFunc}`);
                }
                if (!effectDef) {
                    effectDef = getEffect(passFunc);
                }
            }
            
            for (const pass of stepPasses) {
                if (!pass.uniforms) continue;
                
                for (const [paramName, value] of Object.entries(params)) {
                    if (value === undefined || value === null) continue;
                    
                    if (paramName === 'zoom') {
                        zoomChanged = true;
                    }
                    
                    let spec = null;
                    if (effectDef && effectDef.globals) {
                        spec = effectDef.globals[paramName];
                    }
                    
                    const uniformName = spec?.uniform || paramName;
                    
                    if (uniformName in pass.uniforms) {
                        const converted = this._renderer.convertParameterForUniform(value, spec);
                        pass.uniforms[uniformName] = Array.isArray(converted) ? converted.slice() : converted;
                    }
                }
            }
        }

        if (zoomChanged && pipeline.resize) {
            let zoomValue = 1;
            for (const params of Object.values(this._effectParameterValues)) {
                if (params.zoom !== undefined) {
                    zoomValue = params.zoom;
                    break;
                }
            }
            pipeline.resize(pipeline.width, pipeline.height, zoomValue);
        }
        
        for (const params of Object.values(this._effectParameterValues)) {
            if ('volumeSize' in params && pipeline.setUniform) {
                pipeline.setUniform('volumeSize', params.volumeSize);
                break;
            }
        }
    }
    
    /**
     * Update DSL from effect parameter values
     * @private
     */
    _updateDslFromEffectParams() {
        this._applyEffectParameterValues();
        
        const newDsl = this.regenerateDslFromEffectParams();
        if (newDsl !== null && newDsl !== this.getDsl()) {
            this.setDsl(newDsl);
            this._renderer.currentDsl = newDsl;
        }
    }
    
    // =========================================================================
    // Effect Selection and Pipeline Management
    // =========================================================================
    
    /**
     * Initialize parameter values from effect defaults
     * @param {object} effect - Effect object
     */
    initParameterValues(effect) {
        this._parameterValues = {};
        if (effect.instance && effect.instance.globals) {
            for (const [key, spec] of Object.entries(effect.instance.globals)) {
                if (spec.default !== undefined) {
                    this._parameterValues[key] = cloneParamValue(spec.default);
                }
            }
        }
    }
    
    /**
     * Get zoom value from parameters
     * @param {object} [effect] - Current effect
     * @returns {number} Zoom value
     */
    getZoomValue(effect) {
        return this._parameterValues.zoom || 
            (effect?.instance?.globals?.zoom?.default) || 1;
    }
    
    /**
     * Format a compilation error for display
     * @param {Error} err - Error object
     * @returns {string} Formatted error message
     */
    formatCompilationError(err) {
        if (err.code === 'ERR_COMPILATION_FAILED' && Array.isArray(err.diagnostics)) {
            return err.diagnostics
                .filter(d => d.severity === 'error')
                .map(d => {
                    let msg = d.message || 'Unknown error';
                    if (d.location) {
                        msg += ` (line ${d.location.line}, col ${d.location.column})`;
                    }
                    return msg;
                })
                .join('; ') || 'Unknown compilation error';
        }
        return err.message || err.detail || (typeof err === 'object' ? JSON.stringify(err) : String(err));
    }
}

// Re-export utilities that might be needed externally
export { cloneParamValue, isStarterEffect, hasTexSurfaceParam, is3dGenerator, is3dProcessor, getEffect };
