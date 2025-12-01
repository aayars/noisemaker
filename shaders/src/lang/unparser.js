/**
 * DSL Unparser - Converts AST back to source code.
 * 
 * This module takes a parsed/validated AST and serializes it back to valid DSL source.
 * It preserves the semantic structure while regenerating the text representation.
 */

/**
 * Format a value for DSL output
 * @param {any} value - The value to format
 * @param {object} spec - Optional parameter spec for type hints
 * @param {function} customFormatter - Optional custom formatter function(value, spec) => string|null
 * @returns {string} Formatted string representation
 */
function formatValue(value, spec, customFormatter) {
    // Try custom formatter first if provided
    if (customFormatter) {
        const custom = customFormatter(value, spec);
        if (custom !== null && custom !== undefined) {
            return custom;
        }
    }
    
    if (value === null || value === undefined) {
        return 'null';
    }
    
    if (typeof value === 'boolean') {
        return value ? 'true' : 'false';
    }
    
    if (typeof value === 'number') {
        // Format numbers nicely - avoid excessive precision
        if (Number.isInteger(value)) {
            return String(value);
        }
        // Round to reasonable precision
        const rounded = Math.round(value * 1000000) / 1000000;
        return String(rounded);
    }
    
    if (typeof value === 'string') {
        // Check if it's an enum path (contains dots and no spaces)
        if (value.includes('.') && !value.includes(' ')) {
            return value; // Enum path, no quotes
        }
        // Regular string, quote it
        return `"${value.replace(/"/g, '\\"')}"`;
    }
    
    if (Array.isArray(value)) {
        // Color array [r, g, b] or [r, g, b, a]
        if (value.length >= 3 && value.length <= 4 && value.every(v => typeof v === 'number')) {
            // Convert to hex color
            const toHex = (n) => {
                const clamped = Math.max(0, Math.min(255, Math.round(n * 255)));
                return clamped.toString(16).padStart(2, '0');
            };
            const hex = `#${toHex(value[0])}${toHex(value[1])}${toHex(value[2])}`;
            return hex;
        }
        return `[${value.map(v => formatValue(v, null, customFormatter)).join(', ')}]`;
    }
    
    if (typeof value === 'object') {
        // Handle special AST node types
        if (value.type === 'OutputRef') {
            return value.name;
        }
        if (value.type === 'FeedbackRef') {
            return value.name;
        }
        if (value.type === 'SourceRef') {
            return value.name;
        }
        if (value.type === 'Member') {
            return value.path.join('.');
        }
        if (value.type === 'Number') {
            return formatValue(value.value, spec, customFormatter);
        }
        if (value.type === 'String') {
            return formatValue(value.value, spec, customFormatter);
        }
        if (value.type === 'Boolean') {
            return value.value ? 'true' : 'false';
        }
        // Surface reference
        if (value.kind === 'output' || value.kind === 'feedback' || value.kind === 'source') {
            return value.name;
        }
    }
    
    return String(value);
}

/**
 * Unparse a Call node
 * @param {object} call - Call AST node
 * @param {object} options - Unparse options (includes customFormatter)
 * @returns {string} DSL source for the call
 */
function unparseCall(call, options = {}) {
    const name = call.name;
    const parts = [];
    const customFormatter = options.customFormatter || null;
    
    // Handle kwargs (named arguments)
    if (call.kwargs && Object.keys(call.kwargs).length > 0) {
        for (const [key, value] of Object.entries(call.kwargs)) {
            // Get spec from options if available
            const spec = options.specs?.[key] || null;
            parts.push(`${key}: ${formatValue(value, spec, customFormatter)}`);
        }
    }
    
    // Handle positional args
    if (call.args && call.args.length > 0) {
        for (const arg of call.args) {
            parts.push(formatValue(arg, null, customFormatter));
        }
    }
    
    return `${name}(${parts.join(', ')})`;
}

/**
 * Unparse a chain of calls
 * @param {Array} chain - Array of Call nodes
 * @param {object} options - Unparse options
 * @returns {string} DSL source for the chain
 */
function unparseChain(chain, options = {}) {
    return chain.map(call => unparseCall(call, options)).join('.');
}

/**
 * Unparse a plan (statement with chain and optional output)
 * @param {object} plan - Plan object from validator
 * @param {object} options - Unparse options
 * @returns {string} DSL source for the plan
 */
function unparsePlan(plan, options = {}) {
    if (!plan.chain || plan.chain.length === 0) {
        return '';
    }
    
    let result = '';
    
    // Build chain from steps
    const callParts = [];
    for (const step of plan.chain) {
        const call = {
            name: step.op,
            kwargs: {},
            args: []
        };
        
        // Convert step.args back to kwargs format
        if (step.args) {
            for (const [key, value] of Object.entries(step.args)) {
                // Skip internal properties
                if (key === 'from' || key === 'temp') continue;
                
                // Handle surface references
                if (value && typeof value === 'object' && value.kind) {
                    call.kwargs[key] = value.name;
                } else {
                    call.kwargs[key] = value;
                }
            }
        }
        
        callParts.push(unparseCall(call, options));
    }
    
    result = callParts.join('.');
    
    // Add output directive
    if (plan.out) {
        result += `.out(${plan.out})`;
    }
    
    return result;
}

/**
 * Unparse an entire program
 * @param {object} compiled - Compiled result from compile()
 * @param {object} overrides - Map of stepIndex -> parameter overrides
 * @param {object} options - Unparse options
 *   - customFormatter: function(value, spec) => string|null
 *   - getEffectDef: function(effectName, namespace) => effectDef|null
 * @returns {string} Complete DSL source
 */
export function unparse(compiled, overrides = {}, options = {}) {
    const lines = [];
    const customFormatter = options.customFormatter || null;
    const getEffectDef = options.getEffectDef || null;
    const searchNamespaces = compiled.searchNamespaces || [];
    
    // Add search directive if present
    if (searchNamespaces.length > 0) {
        lines.push(`search ${searchNamespaces.join(', ')}`);
    }
    
    // Track global step index across all plans
    let globalStepIndex = 0;
    
    // Process each plan
    for (const plan of (compiled.plans || [])) {
        if (!plan.chain || plan.chain.length === 0) continue;
        
        const callParts = [];
        
        for (const step of plan.chain) {
            // Check for parameter overrides for this step
            const stepOverrides = overrides[globalStepIndex] || {};
            
            // Get effect definition if callback provided
            let effectDef = null;
            if (getEffectDef) {
                const namespace = step.namespace?.namespace || step.namespace?.resolved || null;
                effectDef = getEffectDef(step.op, namespace);
            }
            
            // Determine the call name - strip namespace prefix if it's in search namespaces
            let callName = step.op;
            for (const ns of searchNamespaces) {
                const prefix = `${ns}.`;
                if (callName.startsWith(prefix)) {
                    callName = callName.slice(prefix.length);
                    break;
                }
            }
            
            const call = {
                name: callName,
                kwargs: {},
                args: []
            };
            
            // Start with original args
            if (step.args) {
                for (const [key, value] of Object.entries(step.args)) {
                    // Skip internal properties
                    if (key === 'from' || key === 'temp') continue;
                    
                    // Handle surface references
                    if (value && typeof value === 'object' && value.kind) {
                        call.kwargs[key] = value.name;
                    } else {
                        call.kwargs[key] = value;
                    }
                }
            }
            
            // Apply overrides
            for (const [key, value] of Object.entries(stepOverrides)) {
                call.kwargs[key] = value;
            }
            
            // Build specs map from effect definition
            const specs = effectDef?.globals || {};
            
            callParts.push(unparseCall(call, { customFormatter, specs }));
            globalStepIndex++;
        }
        
        let line = callParts.join('.');
        
        // Add output directive
        if (plan.out) {
            const outName = typeof plan.out === 'string' ? plan.out : plan.out.name;
            line += `.out(${outName})`;
        }
        
        lines.push(line);
    }
    
    // Add render directive if present
    if (compiled.render) {
        lines.push(`render(${compiled.render.name})`);
    }
    
    return lines.join('\n');
}

/**
 * Apply parameter updates to a compiled DSL and regenerate source
 * @param {string} originalDsl - Original DSL source
 * @param {object} compile - The compile function
 * @param {object} parameterUpdates - Map of stepIndex -> {paramName: value}
 * @returns {string} Updated DSL source
 */
export function applyParameterUpdates(originalDsl, compileFn, parameterUpdates) {
    // Parse the original DSL
    const compiled = compileFn(originalDsl);
    if (!compiled || !compiled.plans) {
        return originalDsl;
    }
    
    // Extract search namespaces from original source
    const searchMatch = originalDsl.match(/^search\s+(\S.*?)$/m);
    if (searchMatch) {
        compiled.searchNamespaces = searchMatch[1].split(/\s*,\s*/);
    }
    
    // Generate new source with overrides
    return unparse(compiled, parameterUpdates, {});
}

export { formatValue, unparseCall, unparseChain, unparsePlan };
