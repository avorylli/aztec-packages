#!/usr/bin/env bash
source $(git rev-parse --show-toplevel)/ci3/source
source $ci3/source_redis

cmd=${1:-}
arch=${ARCH:-$(arch)}
NO_TERMINATE=${NO_TERMINATE:-0}
BRANCH=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
ci3_workflow_id=128853861

function echo_cmd {
  local name=$1
  shift
  printf "${blue}${bold}%12s${reset}: %s\n" $name "$(echo $@ | sed 's/\.\\n/.\n             /g')"
}

function print_usage {
  echo "usage: $(basename $0) <cmd>"
  echo
  echo_cmd "ec2"            "Launch an ec2 instance and './bootstrap.sh ci' on it.\n" \
                            "Exactly what Github Action's does, but doesn't touch GA."
  echo_cmd "ec2-no-cache"   "Same as ec2, but perform a full build and test (disable build and test cache)."
  echo_cmd "ec2-test"       "Same as ec2, but run all tests (disable test cache)."
  echo_cmd "ec2-grind"      "Same as ec2-test, but run over N instances."
  echo_cmd "ec2-shell"      "Launch an ec2 instance, clone the repo and drop into a shell."
  echo_cmd "local"          "Clone your last commit into a fresh container and bootstrap on local hardware."
  echo_cmd "run"            "Same as calling trigger, then rlog."
  echo_cmd "shell"          "Jump into a new shell on the current running build instance.\n" \
                            "Can provide a command to run instead of dropping into a shell, e.g. 'ci shell ls'."
  echo_cmd "trigger"        "Trigger the GA workflow on the PR associated with the current branch.\n" \
                            "Effectively the same as ec2, only the results will be tracked on your PR."
  echo_cmd "rlog"           "Will tail the logs of the latest GA run, or tail/dump the given GA run id."
  echo_cmd "ilog"           "Will tail the logs of the current running build instance."
  echo_cmd "dlog"           "Display the log of the given denoise log id."
  echo_cmd "llog"           "Tail the live log of a given log id."
  echo_cmd "tlog"           "Display the last log of the given test command as output by test_cmds."
  echo_cmd "tilog"          "Tail the live log of a given test command as output by test_cmds."
  echo_cmd "shell-host"     "Connect to host instance of the current running build."
  echo_cmd "draft"          "Mark current PR as draft (no automatic CI runs when pushing)."
  echo_cmd "uncached-tests" "List tests that will run/did not finish in a CI pass for this commit."
  echo_cmd "ready"          "Mark current PR as ready (enable automatic CI runs when pushing)."
}

[ -n "$cmd" ] && shift

instance_name=${INSTANCE_NAME:-$(echo -n "$BRANCH" | tr -c 'a-zA-Z0-9-' '_')_${arch}}
[ -n "${INSTANCE_POSTFIX:-}" ] && instance_name+="_$INSTANCE_POSTFIX"

function get_ip_for_instance {
  ip=$(aws ec2 describe-instances \
    --region us-east-2 \
    --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[0].PublicIpAddress" \
    --output text)
}

function get_latest_run_id {
  gh run list --workflow $ci3_workflow_id -b $BRANCH --limit 1 --json databaseId -q .[0].databaseId
}

function tail_live_instance {
  get_ip_for_instance
  [ -z "$ip" ] && return 1;
  ssh -F $ci3/aws/build_instance_ssh_config -q -t -o ConnectTimeout=5 ubuntu@$ip "
    trap 'exit 0' SIGINT
    docker ps -a --filter name=aztec_build --format '{{.Names}}' | grep -q '^aztec_build$' || exit 1
    docker logs -f aztec_build
  "
}

case "$cmd" in
  "ec2")
    # Spin up ec2 instance and ci bootstrap with shell on failure.
    export USE_TEST_CACHE=${USE_TEST_CACHE:-1}
    exec bootstrap_ec2
    ;;
  "ec2-no-cache")
    # Disable the build and test cache.
    export NO_CACHE=1
    export USE_TEST_CACHE=0
    exec bootstrap_ec2
    ;;
  "ec2-test")
    # Can use the build cache, but don't use the test cache.
    export USE_TEST_CACHE=0
    exec bootstrap_ec2
    ;;
  "ec2-shell")
    # Spin up ec2 instance, clone, and drop into shell.
    # False triggers the shell on fail.
    exec bootstrap_ec2 "false"
    ;;
  "ec2-grind")
    # Same as ec2-test but repeat it over arg1 instances.
    export CI_FULL=1
    export USE_TEST_CACHE=0
    num=${1:-5}
    seq 0 $((num - 1)) | parallel --tag --line-buffered \
      'INSTANCE_POSTFIX=${USER}_{} bootstrap_ec2 2>&1 | cache_log "Grind {}"'
    ;;
  "local")
    # Create container with clone of local repo and bootstrap.
    bootstrap_local "$@"
    ;;
  "run")
    # Trigger a GA workflow for current branch PR and tail logs.
    $0 trigger
    $0 rlog
    ;;
  "shell")
    get_ip_for_instance
    [ -z "$ip" ] && echo "No instance found: $instance_name" && exit 1
    [ "$#" -eq 0 ] && set -- "zsh" || true
    ssh -tq -F $ci3/aws/build_instance_ssh_config ubuntu@$ip \
      "docker start aztec_build &>/dev/null || true && docker exec -it --user aztec-dev aztec_build $@"
    ;;
  "trigger")
    # Trigger workflow.
    # We use this label trick because triggering the workflow direct doesn't associate with the PR.
    pr_number=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')
    if [ -z "$pr_number" ]; then
      echo "No pull request found for branch $BRANCH."
      exit 1
    fi
    gh pr edit "$pr_number" --remove-label "trigger-workflow" &> /dev/null
    gh pr edit "$pr_number" --add-label "trigger-workflow" &> /dev/null
    sleep 1
    gh pr edit "$pr_number" --remove-label "trigger-workflow" &> /dev/null
    run_id=$(get_latest_run_id)
    echo "In progress..." | redis_setexz $run_id 3600
    echo -e "Triggered CI for PR: $pr_number (ci rlog ${yellow}$run_id${reset})"
    ;;
  "rlog")
    [ -z "${1:-}" ] && run_id=$(get_latest_run_id) || run_id=$1
    output=$(redis_getz $run_id)
    if [ -z "$output" ] || [ "$output" == "In progress..." ]; then
      # If we're in progress, tail live logs from launched instance.
      exec $0 ilog
    else
      echo "$output" | $PAGER
    fi
    ;;
  "ilog")
    while ! tail_live_instance; do
      echo "Waiting on instance with name: $instance_name"
      sleep 10
    done
    ;;
  "dlog")
    if [ "$CI_REDIS_AVAILABLE" -ne 1 ]; then
      echo "No redis available for log query."
      exit 1
    fi
    pager=${PAGER:-less}
    [ ! -t 0 ] && pager=cat
    redis_getz $1 | $pager
    ;;
  "tlog")
    if [ "$CI_REDIS_AVAILABLE" -ne 1 ]; then
      echo "No redis available for test query."
      exit 1
    fi
    pager=${PAGER:-less}
    key=$(hash_str "$1")
    log_key=$(redis_cli --raw GET $key)
    if [ -n "$log_key" ]; then
      redis_getz $log_key | $pager
    else
      echo "No test log found for: $key"
      exit 1
    fi
    ;;
  "tilog")
    # Given a test cmd, tail it's a live log.
    ./ci.sh llog $(hash_str "$1")
  ;;
  "llog")
    # If the log file exists locally, tail it, otherwise assume it's remote.
    key=$1
    if [ -f /tmp/$key ]; then
      tail -F -n +1 /tmp/$key
    else
      ./ci.sh shell tail -F -n +1 /tmp/$key
    fi
  ;;
  "shell-host")
    get_ip_for_instance
    [ -z "$ip" ] && echo "No instance found: $instance_name" && exit 1
    ssh -t -F $ci3/aws/build_instance_ssh_config ubuntu@$ip
    ;;
  "kill")
    existing_instance=$(aws ec2 describe-instances \
      --region us-east-2 \
      --filters "Name=tag:Name,Values=$instance_name" \
      --query "Reservations[].Instances[?State.Name!='terminated'].InstanceId[]" \
      --output text)
    if [ -n "$existing_instance" ]; then
      aws_terminate_instance $existing_instance
    fi
    ;;
  "draft")
    pr_number=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')
    if [ -n "$pr_number" ]; then
      gh pr ready "$pr_number" --undo
      echo "Pull request #$pr_number has been set to draft."
    else
      echo "No pull request found for branch $BRANCH."
    fi
    ;;
  "ready")
    pr_number=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')
    if [ -n "$pr_number" ]; then
      gh pr ready "$pr_number"
      echo "Pull request #$pr_number has been set to ready."
    else
      echo "No pull request found for branch $BRANCH."
    fi
    ;;
  "gha-url")
    workflow_id=$(gh workflow list --all --json name,id -q '.[] | select(.name == "CI").id')
    run_url=$(gh run list --workflow $workflow_id -b $BRANCH --limit 1 --json url -q '.[0].url')
    if [ -z "$run_url" ]; then
      echo "No workflow runs found for branch '$BRANCH'."
      exit 1
    fi
    echo "$run_url"
    ;;
  "pr-url")
    # Fetch the current PR associated with the branch
    pr_url=$(gh pr list --head "$BRANCH" --limit 1 --json url -q '.[0].url')
    if [ -z "$pr_url" ]; then
      echo "No pull request found for branch '$BRANCH'."
      exit 1
    fi
    echo "$pr_url"
    ;;
  "deploy")
    VERSION_TAG=$1
    ;;
  "watch")
    watch_ci "$@"
    ;;
  "help"|"")
    print_usage
    ;;
  "gh-bench")
    export CI=1
    # Set up preferred commit attribution (needed by noir checkout).
    git config --global user.email "tech@aztecprotocol.com"
    git config --global user.name "AztecBot"
    # Run benchmark logic for github actions.
    bb_hash=$(barretenberg/bootstrap.sh hash)
    # Protocol circuit benchmarks are published on each commit
    npc_hash=$(git rev-list -n 1 ${AZTEC_CACHE_COMMIT:-HEAD})
    # Simulator benchmarks are published on each commit
    sim_hash=$(git rev-list -n 1 ${AZTEC_CACHE_COMMIT:-HEAD})
    l1_hash=$(l1-contracts/bootstrap.sh hash)
    yp_hash=$(yarn-project/bootstrap.sh hash)

    if [ "$bb_hash" == disabled-cache ] || [ "$yp_hash" == disabled-cache ]; then
      echo "Error, can't publish benchmarks due to unstaged changes."
      git status -s
      exit 1
    fi

    prev_bb_hash=$(AZTEC_CACHE_COMMIT=HEAD^ barretenberg/bootstrap.sh hash)
    prev_yp_hash=$(AZTEC_CACHE_COMMIT=HEAD^ yarn-project/bootstrap.sh hash)

    # barretenberg benchmarks.
    if [ "$bb_hash" == "$prev_bb_hash" ]; then
      echo "No changes since last master, skipping barretenberg benchmark publishing."
      echo "SKIP_BB_BENCH=true" >> $GITHUB_ENV
    else
      cache_download barretenberg-bench-results-$bb_hash.tar.gz
    fi

    # noir-protocol-circuits benchmarks.
    cache_download noir-protocol-circuits-bench-results-$npc_hash.tar.gz
    # aztec simulator benchmarks.
    cache_download simulator-bench-results-$sim_hash.tar.gz
    # L1 gas benchmark
    cache_download l1-gas-bench-results-$l1_hash.tar.gz

    # yarn-project benchmarks.
    if [ "$yp_hash" == "$prev_yp_hash" ]; then
      echo "No changes since last master, skipping yarn-project benchmark publishing."
      echo "SKIP_YP_BENCH=true" >> $GITHUB_ENV
    else
      cache_download yarn-project-bench-results-$yp_hash.tar.gz
      # TODO reenable
      # ./cache_download yarn-project-p2p-bench-results-$(git rev-parse HEAD).tar.gz
    fi
    ;;
  "uncached-tests")
    if [ -z "$CI_REDIS_AVAILABLE" ]; then
      echo "Not connected to CI redis."
      exit 1
    fi
    ./bootstrap.sh test_cmds | \
       grep -Ev -f <(yq e '.tests[] | select(.skip == true) | .regex' $root/.test_patterns.yml) | \
       USE_TEST_CACHE=1 filter_cached_test_cmd
    ;;
  *)
    echo "Unknown command: $cmd, see ./ci.sh help"
    exit 1
    ;;
esac
