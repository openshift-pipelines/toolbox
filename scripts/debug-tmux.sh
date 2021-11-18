#!/usr/bin/env bash
#
# This script start a TMUX session targeting a cluster to debug it
KUBECONFIG_NAME=$1

set -eu -o pipefail

#SESSION_NAME=${KUBECONFIG_NAME}
SESSION_NAME=$(echo ${KUBECONFIG_NAME} | tr '.' '_' )

KUBECONFIG=${HOME}/.kube/${KUBECONFIG_NAME}

# Guess Namespace
# FIXME: this is ugly
echo "Detecting…"
TEKTON_NAMESPACE=""
kubectl --kubeconfig="${KUBECONFIG}" get namespace | grep "tekton-pipelines" && {
    echo "  Running in kubernetes, tekton-pipelines namespace"
    TEKTON_NAMESPACE="tekton-pipelines"
} || {
    echo -n ""
}
kubectl --kubeconfig="${KUBECONFIG}" get namespace | grep "openshift-pipelines" && {
    echo "  Running in kubernetes, tekton-pipelines namespace"
    TEKTON_NAMESPACE="openshift-pipelines"
} || {
    echo -n ""
}
if [[ $TEKTON_NAMESPACE == "" ]]; then
    echo "Tekton is not present in the cluster, nothing to debug…"
    exit 1
fi

# FIXME: add helpers like
# - watch tekton resource in the namespace
# - watch pods in this namespace, …

echo "Creating a session ${SESSION_NAME}…"
tmux new-session -d -s ${SESSION_NAME} -n main
tmux setenv -t ${SESSION_NAME} KUBECONFIG ${KUBECONFIG}
tmux send-keys -t ${SESSION_NAME}:main "export KUBECONFIG=${KUBECONFIG}" C-m
tmux send-keys -t ${SESSION_NAME}:main "tmux new-window -n controllers-logs kail --since=1h --ns=${TEKTON_NAMESPACE}" C-m
if [[ $TEKTON_NAMESPACE == "openshift-pipelines" ]]; then
    tmux send-keys -t ${SESSION_NAME}:main "tmux new-window -n operator-logs kail --since=1h --ns=openshift-operators --deploy=openshift-pipelines-operator" C-m
elif [[ $TEKTON_NAMESPACE == "tekton-pipelines" ]]; then
    tmux send-keys -t ${SESSION_NAME}:main "tmux new-window -n operator-logs kail --since=1h --ns=tekton-operator" C-m
fi

tmux send-keys -t ${SESSION_NAME}:main "tmux select-window -t main" C-m
tmux send-keys -t ${SESSION_NAME}:main C-l

echo "Attaching the session…"
tmux attach-session -t ${SESSION_NAME}
