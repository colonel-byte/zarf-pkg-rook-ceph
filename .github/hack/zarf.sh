#!/usr/bin/env bash

set -u
set -o pipefail

declare -a FLAVOR=("upstream")
declare -a COMPONENTS=("operator" "cluster")
declare -a COMPONENTS_TYPES=("")

for flavor in "${FLAVOR[@]}"; do
  rm -rf .direnv/$flavor
  mkdir -p .direnv/$flavor
  zarf dev find-images --flavor $flavor --skip-cosign . 2>/dev/null > .direnv/$flavor/out.yml
  echo "::debug::flavor='${flavor}'"
  for component in "${COMPONENTS[@]}"; do
    echo "::debug::component='${component}'"
    for type in "${COMPONENTS_TYPES[@]}"; do
      echo "::debug::type='${type}'"
      export yq_search=$(printf '.components[] | select(.name == "%s%s-images" and .only.flavor == "%s") | path | .[1]' "$component" "$type" "$flavor")
      echo "::debug::yq_search='${yq_search}'"
      export yq_index=$(yq "$yq_search" zarf.yaml)
      echo "::debug::yq_index='${yq_index}'"
      export yq_images=$(printf '(select(fi == 1) | .components[] | select(.name == "%s-chart") | .images | ... head_comment="") as $img' "$component")
      echo "::debug::yq_images='${yq_images}'"
      export yq_charts=$(printf '(select(fi == 0) | .x-charts.%s) as $cht' "$component")
      echo "::debug::yq_charts='${yq_charts}'"
      export yq_update=$(printf '(select(fi == 0) | .components[%s].images = ($img + $cht | sort))' "$yq_index")
      echo "::debug::yq_update='${yq_update}'"
      yq ea -i "$yq_images | $yq_charts | $yq_update" zarf.yaml .direnv/$flavor/out.yml
    done
  done
done
