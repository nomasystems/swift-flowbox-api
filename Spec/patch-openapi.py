import json
import os
import sys

SPEC_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
UPSTREAM = os.path.join(SPEC_DIRECTORY, "upstream-openapi.json")
PATCHED = os.path.join(SPEC_DIRECTORY, "openapi.json")

SECURITY_SCHEME = "apiKey"
API_KEY_HEADER = "api-key"


def operation(document, operation_id):
    for path_item in document["paths"].values():
        for method in path_item.values():
            if isinstance(method, dict) and method.get("operationId") == operation_id:
                return method
    sys.exit(f"error: operation {operation_id} not found in upstream spec")


def parameter(op, name):
    for param in op.get("parameters", []):
        if param["name"] == name:
            return param
    sys.exit(f"error: parameter {name} not found in {op['operationId']}")


def ok_json_schema(op):
    return op["responses"]["200"]["content"]["application/json"]["schema"]


def patch_cursor_is_integer(document):
    posts = operation(document, "GetPostsByFlowKey")
    data = ok_json_schema(posts)["properties"]["data"]["properties"]
    if "$ref" not in data["cursor"]:
        sys.exit("error: upstream cursor is no longer a $ref, review this patch")
    data["cursor"] = {"type": "integer", "description": "Page counter of the next page, send it back as the cursor query parameter."}
    parameter(posts, "cursor")["schema"] = {"type": "integer"}


def patch_api_key_is_security_scheme(document):
    for path_item in document["paths"].values():
        for method in path_item.values():
            if isinstance(method, dict) and "parameters" in method:
                method["parameters"] = [
                    param for param in method["parameters"]
                    if not (param["in"] == "header" and param["name"] == API_KEY_HEADER)
                ]
    document.setdefault("components", {})["securitySchemes"] = {
        SECURITY_SCHEME: {"type": "apiKey", "in": "header", "name": API_KEY_HEADER}
    }
    document["security"] = [{SECURITY_SCHEME: []}]


def main():
    with open(UPSTREAM) as handle:
        document = json.load(handle)
    patch_cursor_is_integer(document)
    patch_api_key_is_security_scheme(document)
    with open(PATCHED, "w") as handle:
        json.dump(document, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


main()
