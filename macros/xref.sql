{% macro xref() %}
-- extract user-provided positional and keyword arguments
  {% set version = kwargs.get('version') %}
   {%- if (varargs | length) == 1 -%}
    {% set modelname = varargs[0] %}
{%- else -%}
    {% set packagename = varargs[0] %}
    {% set modelname = varargs[1] %}
{% endif %}
-- call builtins.ref based on provided positional arguments
{% set rel = None %}
{% if packagename is not none %}
    -- if we do a cross ref, we change the database based on the current context
    {% set rel = builtins.ref(packagename, modelname, version=version) %}
    {% set env_id = env_var("DBT_ENV_ID") %}
    {% set current_db = rel.database %}
    {% set newrel = rel.replace_path(database=current_db[:-1] ~ env_id) %}
{% else %}
    {% set newrel = builtins.ref(modelname, version=version) %}
{% endif %}

-- finally, we return the new relation
{% do return(newrel) %}
{% endmacro %}