#!/bin/sh
set -eu

generator_tag="1.13.1"
upstream_url="https://api.swaggerhub.com/apis/FlowboxAB/External-API/v2"

package="$(cd "$(dirname "$0")" && pwd)"
tools="${package}/.build/generator"
binary="${tools}/src/.build/release/swift-openapi-generator"
output="${package}/Sources/FlowboxAPI"
upstream="${package}/Spec/upstream-openapi.json"

cd "${package}"

if [ "${1:-}" = "--refresh" ] || [ ! -f "${upstream}" ]; then
    curl -fsS -L -H "Accept: application/json" -o "${upstream}" "${upstream_url}"
    /usr/bin/python3 -c "
import json
path = 'Spec/upstream-openapi.json'
document = json.load(open(path))
open(path, 'w').write(json.dumps(document, indent=2, ensure_ascii=False) + '\n')
"
    echo "Spec/upstream-openapi.json downloaded"
fi

if [ ! -x "${binary}" ]; then
    rm -rf "${tools}/src"
    mkdir -p "${tools}"
    git clone --quiet --depth 1 --branch "${generator_tag}" https://github.com/apple/swift-openapi-generator "${tools}/src"
    (cd "${tools}/src" && swift build --configuration release --product swift-openapi-generator)
fi

/usr/bin/python3 Spec/patch-openapi.py

rm -rf "${output}"
mkdir -p "${output}"
"${binary}" generate Spec/openapi.json --config Spec/openapi-generator-config.yaml --output-directory "${output}"

perl -pi -e 's/\bpublic import /import /' "${output}"/*.swift

cat > "${output}/Exports.swift" <<'SWIFT'
@_exported import OpenAPIRuntime
@_exported import OpenAPIURLSession
@_exported import HTTPTypes
SWIFT

echo "Generated sources written to Sources/FlowboxAPI"
