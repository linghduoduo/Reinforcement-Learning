#!/bin/bash

# Test nightly release: ./test_release.sh nightly
# Test stable release: ./test_release.sh stable

# Exit if any process returns non-zero status.
set -e
# Display the commands being run in logs, which are replicated to sponge.
set -x

if [[ $# -lt 1 ]] ; then
  echo "Usage:"
  echo "test_release [nightly|stable|stable_tf1.x]"
  exit 1
fi

run_tests() {
  echo "run_tests $1 $2"

  # Install necessary python version
  pyenv install --list
  pyenv install -s $1
  pyenv global $1

  TMP=$(mktemp -d)
  # Create and activate a virtualenv to specify python version and test in
  # isolated environment. Note that we don't actually have to cd'ed into a
  # virtualenv directory to use it; we just need to source bin/activate into the
  # current shell.
  VENV_PATH=${TMP}/virtualenv/$1
  virtualenv "${VENV_PATH}"
  source ${VENV_PATH}/bin/activate


  # TensorFlow isn't a regular dependency because there are many different pip
  # packages a user might have installed.
  if [[ $2 == "nightly" ]] ; then
    pip install tf-nightly

    # Run the tests
    python setup.py test

    # Install tf_agents package.
    WHEEL_PATH=${TMP}/wheel/$1
    ./pip_pkg.sh ${WHEEL_PATH}/
  elif [[ $2 == "stable_tf1.x" ]] ; then
    pip install tensorflow==1.15.0 \
      tensorflow-estimator==1.15.1 \
      gast==0.2.2

    # Run the tests
    python setup.py test --release

    # Install tf_agents package.
    WHEEL_PATH=${TMP}/wheel/$1
    ./pip_pkg.sh ${WHEEL_PATH}/ --release
  elif [[ $2 == "stable" ]] ; then
    pip install tensorflow tensorflow-probability

    # Run the tests
    python setup.py test --release

    # Install tf_agents package.
    WHEEL_PATH=${TMP}/wheel/$1
    ./pip_pkg.sh ${WHEEL_PATH}/ --release
  else
    echo "Error unknown option only [nightly|stable]"
    exit
  fi

  pip install ${WHEEL_PATH}/tf_agents*.whl

  # Move away from repo directory so "import tf_agents" refers to the
  # installed wheel and not to the local fs.
  (cd $(mktemp -d) && python -c 'import tf_agents')

  # Deactivate virtualenv
  deactivate
}

if ! which cmake > /dev/null; then
   echo -e "cmake not found! needed for atari_py tests. Install? (y/n) \c"
   read
   if "$REPLY" = "y"; then
      sudo apt-get install -y cmake zlib1g-dev
   fi
fi

# Test on Python2.7
run_tests "2.7.14" $1
# Test on Python3.6.1
run_tests "3.6.1" $1
