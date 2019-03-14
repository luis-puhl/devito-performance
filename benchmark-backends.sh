# set -x

OUTPUT_DIR=devito.bench.`date +%Y-%m-%d`

missing=''
# icpc: Intel C++ compiler
for required in mkdir python date numactl uname lscpu uname numactl numastat top; do
  if ! [ -x "$(command -v $required)" ]; then
    echo "Error: '$required' is not installed." >&2
    missing=$missing$required', '
  fi
done

lscpu         > $OUTPUT_DIR/LSCPU.log      2>&1
uname -a      > $OUTPUT_DIR/UNAME_A.log    2>&1
numactl -H    > $OUTPUT_DIR/NUMACTL_H.log  2>&1
numastat -m   > $OUTPUT_DIR/NUMASTAT_M.log 2>&1
icpc -v       > $OUTPUT_DIR/ICPC_V.log     2>&1

if [ ! -z $missing ]; then
  echo "Those programs '$missing' are missing dependecies" >&2
  exit 1
fi
if [ ! -e $YASK_HOME ]; then
  echo "Env YASK_HOME is not set" >&2
  exit 1
fi

# This depends on hostname, maybe other way?
numactl="numactl --preferred=0"
if [[ `hostname | grep -c skl` > 0 ]]; then
  DEVITO_PLATFORM="skx"
  numactl="numactl --cpubind=1"
fi
if [[ `hostname | grep -c knl` > 0 ]]; then
  DEVITO_PLATFORM="knl"
  numactl="numactl --preferred=0"
fi

DEVITO_DIR=`pwd`'/devito'
PYTHON_VENV=`pwd`'/venv'
PYTHON_VENV_BIN=$PYTHON_VENV'/bin'
echo '' > $OUTPUT_DIR/pip.log
if [[ 'install' == $1 ]]; then
  if [ ! -d $PYTHON_VENV ]; then
    echo "[install] create venv"
    python3 -m venv venv
  fi
  for item in "-upgrade pip" "r `pwd`/requirements.txt" "r `pwd`/requirements-optional.txt"; do
    echo "[install] $item"
    $PYTHON_VENV_BIN/pip install -$item >> $OUTPUT_DIR/pip.log
    if [ $? -ne 0 ]; then
      cat $OUTPUT_DIR/pip.log
      exit 1
    fi
  done
  echo "[install] done"
fi

echo "[python] checking dependencies"
cmd="env PYTHONPATH=$DEVITO_DIR \
  $numactl \
  $PYTHON_VENV_BIN/python \
  $DEVITO_DIR/examples/seismic/benchmark.py
"
$cmd > $OUTPUT_DIR/usage.log 2>&1
if [ $? -ne 0 ]; then
  echo "[python] Dependencies failed"
  ModuleNotFoundError=$(cat $OUTPUT_DIR/usage.log | grep 'ModuleNotFoundError: No module named')
  if [ ! -z $ModuleNotFoundError ]; then
    echo ModuleNotFoundError
    req=$(cat $OUTPUT_DIR/usage.log | grep 'ModuleNotFoundError: No module named' | sed -n "s;.*'(.*)'.*;\1;p")
    echo "New requirements $req"
    # cat $OUTPUT_DIR/usage.log | grep 'ModuleNotFoundError: No module named' | sed -n "s;.*'(.*)'.*;\1;p" >> requirements.txt
    exit 1
  fi
  cat $OUTPUT_DIR/usage.log
  exit 1
fi

# backend: DEVITO_BACKEND env
for backend in core yask; do
echo "[testing] $backend"

# problem: 'Problem name' param
for problem in acoustic tti; do

# click.option('-bm', '--bench-mode', is_eager=True,
# callback=from_preset, expose_value=False, default='O2',
# type=click.Choice(['O1', 'O2', 'O3', 'dse', 'dle']),
# help='Choose what to benchmark; ignored if execmode=run'),
if [[ $problem == tti && $backend == core ]]; then
  bench_modes='O3 dse'
else
  bench_modes='O2'
fi
for bench_mode in $bench_modes; do

# click.option('-d', '--shape', default=(50, 50, 50),
# help='Number of grid points along each axis'),
# seq [OPTION]... FIRST INCREMENT LAST
# for grid_shape in `seq 512 256 1024`; do
for grid_shape in `seq 50 50 150`; do

# click.option('-so', '--space-order', type=int, multiple=True,
# callback=default_list, help='Space order of the simulation'),
# for space_order in `seq 4 4 16`; do
for space_order in `seq 2 2 16`; do

# @click.option('-r', '--resultsdir', default='results',
# help='Directory containing results')
dir=`pwd`/$OUTPUT_DIR/$problem/$backend/bm$bench_mode/`hostname`/grid$grid_shape/so$space_order
echo "[testing] $problem $backend $bench_mode $grid_shape $space_order"
mkdir -p $dir

log=$dir/run.log
rm -f $log
touch $log
date >> $log
cat $OUTPUT_DIR/LSCPU.log >> $log
cat $OUTPUT_DIR/ICPC_V.log >> $log
cat $OUTPUT_DIR/UNAME_A.log >> $log
cat $OUTPUT_DIR/NUMACTL_H.log >> $log
cat $OUTPUT_DIR/NUMASTAT_M.log >> $log
top -b -n 1 | head -30 >> $log
echo '' >> $log

if [[ $backend == yask ]]; then
  let "grid_shape_ajusted = $grid_shape - 20"
else
  grid_shape_ajusted=$grid_shape
fi

# @click.option('-x', '--repeats', default=3,
# help='Number of test case repetitions')
nruns=3

# click.option('-t', '--tn', default=250,
# help='End time of the simulation in ms'),
simulation_end_time=1000

# bench(problem, **kwargs): Complete benchmark with multiple simulation and performance parameters.

  # $DEVITO_PLATFORM \
  # DEVITO_ISA=avx512 \
  # DEVITO_ARCH=intel \
cmd="env \
  DEVITO_OPENMP=1 \
  DEVITO_DLE_OPTIONS=blockinner:True \
  DEVITO_DEBUG_COMPILER=1 \
  DEVITO_AUTOTUNING=aggressive \
  DEVITO_BACKEND=$backend \
  DEVITO_LOGGING=DEBUG \
  DEVITO_YASK_AUTOTUNING=preemptive \
  DEVITO_YASK_DUMP=$dir \
  PYTHONPATH=$DEVITO_DIR \
  $numactl \
  $PYTHON_VENV_BIN/python \
  $DEVITO_DIR/examples/seismic/benchmark.py bench \
  --bench-mode $bench_mode \
  --problem $problem \
  --space-order $space_order \
  --time-order 2 \
  --shape $grid_shape_ajusted $grid_shape_ajusted $grid_shape_ajusted \
  --tn $simulation_end_time \
  --repeats $nruns \
  --resultsdir $dir
"

echo $cmd >> $log
# $cmd |& tee -a $log
$cmd >> $log 2>&1
ran_ok=$?
# benchmark_output=$($cmd)
echo "[testing] $problem $backend $bench_mode $grid_shape $space_order return $ran_ok"
date >> $log
echo $benchmark_output >> $log

sleep 1
if [ $ran_ok -gt 128 ]; then
  if [ $ran_ok -eq 130 ]; then
    echo '[testing] Stoping test'
    exit 130
  fi
  echo '[testing] WARING: Not enough memory'
  break
fi
if [ $ran_ok -ne 0 ]; then
  cat $log
  exit $ran_ok
fi

done
done
done
done
done
