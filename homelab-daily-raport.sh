#!/bin/bash
# Version 0.1 Added message and dates etc.
# Version 0.2 Added disk usage and uptime for each node
# Version 0.3 Added memory usage

WEBHOOK_URL="EXAMPLE_WEBHOOK_URL"
DATE=$(date +"%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname)

node_disk() {
  local node=$1
  if [ "$node" = "$HOSTNAME" ]; then
    df -h / 2>/dev/null | tail -1 | awk '{gsub(/%/,"",$5); print $2, $5}'
  else
    local name="node-check-$RANDOM"
    kubectl run "$name" --image=busybox --restart=Never --privileged \
      --overrides="$(cat <<EOF
{"spec":{"nodeName":"$node","containers":[{"name":"c","image":"busybox","command":["chroot","/host","df","-h","/"],"volumeMounts":[{"name":"r","mountPath":"/host"}],"securityContext":{"privileged":true}}],"volumes":[{"name":"r","hostPath":{"path":"/","type":"Directory"}}],"restartPolicy":"Never"}}
EOF
)" >/dev/null 2>&1
    kubectl wait --for=condition=Ready pod/"$name" --timeout=30s >/dev/null 2>&1
    kubectl logs "$name" 2>/dev/null | tail -1 | awk '{gsub(/%/,"",$5); print $2, $5}'
    kubectl delete pod "$name" --now >/dev/null 2>&1
  fi
}

node_memory() {
  local node=$1
  if [ "$node" = "$HOSTNAME" ]; then
    free -m | awk '/^Mem:/{printf "%dMB / %dMB (%d%%)", $3, $2, $3*100/$2}'
  else
    local name="mem-check-$RANDOM"
    kubectl run "$name" --image=busybox --restart=Never --privileged \
      --overrides="$(cat <<EOF
{"spec":{"nodeName":"$node","containers":[{"name":"c","image":"busybox","command":["chroot","/host","free","-m"],"volumeMounts":[{"name":"r","mountPath":"/host"}],"securityContext":{"privileged":true}}],"volumes":[{"name":"r","hostPath":{"path":"/","type":"Directory"}}],"restartPolicy":"Never"}}
EOF
)" >/dev/null 2>&1
    kubectl wait --for=condition=Ready pod/"$name" --timeout=30s >/dev/null 2>&1
    kubectl logs "$name" 2>/dev/null | awk '/^Mem:/{printf "%dMB / %dMB (%d%%)", $3, $2, $3*100/$2}'
    kubectl delete pod "$name" --now >/dev/null 2>&1
  fi
}

node_uptime() {
  local node=$1
  if [ "$node" = "$HOSTNAME" ]; then
    cat /proc/uptime | awk '{d=int($1/86400); h=int(($1%86400)/3600); print d"d "h"h"}'
  else
    local name="uptime-check-$RANDOM"
    kubectl run "$name" --image=busybox --restart=Never --privileged \
      --overrides="$(cat <<EOF
{"spec":{"nodeName":"$node","containers":[{"name":"c","image":"busybox","command":["chroot","/host","cat","/proc/uptime"],"volumeMounts":[{"name":"r","mountPath":"/host"}],"securityContext":{"privileged":true}}],"volumes":[{"name":"r","hostPath":{"path":"/","type":"Directory"}}],"restartPolicy":"Never"}}
EOF
)" >/dev/null 2>&1
    kubectl wait --for=condition=Ready pod/"$name" --timeout=30s >/dev/null 2>&1
    kubectl logs "$name" 2>/dev/null | awk '{d=int($1/86400); h=int(($1%86400)/3600); print d"d "h"h"}'
    kubectl delete pod "$name" --now >/dev/null 2>&1
  fi
}

REPORT=":computer: **Daily Homelab Report — $DATE**"

REPORT+=$'\n\n**:file_cabinet: Nodes:**'
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  read -r size used <<< "$(node_disk "$node")"
  free=$((100 - used))
  mem=$(node_memory "$node")
  up=$(node_uptime "$node")
  REPORT+=$'\n'"• **$node**: ${size} total, ${free}% free — RAM ${mem} — up ${up}"
done

FAILING=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Completed" && $2!~/^(node-check-|uptime-check-|mem-check-)/ {print "`"$1"/"$2"` — "$4}')
if [ -n "$FAILING" ]; then
  REPORT+=$'\n\n''**⚠ Issues:**'
  while IFS= read -r line; do
    REPORT+=$'\n'"• $line"
  done <<< "$FAILING"
fi

curl -s -X POST \
  -H "Content-Type: application/json" \
  --data "$(jq -n --arg content "$REPORT" '{content: $content}')" \
  "$WEBHOOK_URL"
