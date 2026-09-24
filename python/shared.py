"""
Shared string parsing and serialization utilities for object format 'obj:var,val;'
"""

def shared_str2obj(string_val, vartype=1):
    """
    Converts string format 'obj:var,val;' into a list of object dicts.
    Matches MATLAB shared_str2obj.m logic.
    """
    if not string_val:
        return []
    
    cobjects = [obj for obj in string_val.split(';') if obj.strip()]
    objects = []
    
    for iobj, cobj in enumerate(cobjects, start=1):
        cvariables = cobj.split(':')
        obj_name = cvariables[0]
        variables = []
        
        for cvarval_str in cvariables[1:]:
            parts = cvarval_str.split(',')
            if len(parts) >= 2:
                var_name = parts[0]
                raw_val = parts[1]
                try:
                    val_num = float(raw_val)
                    var_value = val_num
                except ValueError:
                    var_value = raw_val
                
                variables.append({
                    'name': var_name,
                    'id': 0,
                    'type': vartype,
                    'role': [''],
                    'value': var_value
                })
        
        objects.append({
            'name': obj_name,
            'id': iobj,
            'type': 'object',
            'variables': variables
        })
        
    return objects


def shared_obj2str(objects):
    """
    Converts object dict list back into string format 'obj:var,val;'.
    Matches MATLAB shared_obj2str.m logic.
    """
    res_str = ""
    for obj in objects:
        objname = obj.get('name', '')
        variables = obj.get('variables', [])
        
        if variables:
            var_parts = []
            for var in variables:
                vname = var.get('name', '')
                vval = var.get('value', '')
                if isinstance(vval, list):
                    vval_str = ":".join([f"{vname},{v}" for v in vval])
                else:
                    vval_str = f"{vname},{vval}"
                var_parts.append(vval_str)
            text_var = ":".join(var_parts)
        else:
            text_var = "null,null"
            
        res_str += f"{objname}:{text_var};"
    return res_str
