#!/usr/bin/env bash

set -u
set -o pipefail

declare -a FLAVOR=("upstream" "registry1")
declare -a COMPONENTS=("operator" "cluster")
declare -a COMPONENTS_TYPES=("")

for flavor in "${FLAVOR[@]}"; do
  rm -rf .direnv/$flavor
  mkdir -p .direnv/$flavor

  echo "::debug::flavor='${flavor}'"
  echo "::debug::discovering images"
  zarf dev find-images --flavor $flavor --skip-cosign . 2>/dev/null > .direnv/$flavor/out.yml
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
      export yq_comments=$(printf '(select(fi == 0) | .components[%s].images[] head_comment="")' "$yq_index")
      echo "::debug::yq_comments='${yq_comments}'"
      yq ea -i "$yq_images | $yq_charts | $yq_update | $yq_comments" zarf.yaml .direnv/$flavor/out.yml
    done
  done
done
