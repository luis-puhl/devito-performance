#! /usr/bin/bash
set -x

if [ ! -e $YASK_HOME ]; then
  exit 1
fi

# backend: DEVITO_BACKEND env
for backend in core yask; do

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
for grid_shape in `seq 512 256 1024`; do

# click.option('-so', '--space-order', type=int, multiple=True,
# callback=default_list, help='Space order of the simulation'),
for space_order in `seq 4 4 16`; do

# @click.option('-r', '--resultsdir', default='results',
# help='Directory containing results')
dir=devito.bench.`date +%Y-%m-%d`/$problem/$backend/bm$bench_mode/`hostname`/grid$grid_shape/so$space_order
mkdir -p $dir

log=$dir/run.log
rm -f $log
touch $log
date >> $log
uname -a >> $log
lscpu >> $log
icpc -v 2>&1 >> $log
uname -a >> $log
numactl -H >> $log
numastat -m >> $log
top -b -n 1 | head -30 >> $log

if [[ $backend == yask ]]; then
  grid_shape_ajusted=$(( $grid_shape - $grid_shapeadj ))
else
  grid_shape_ajusted=$grid_shape
fi

if [[ `hostname | grep -c skl` > 0 ]]; then
  plat="skx"
  numactl="numactl --cpubind=1"
else
  plat="knl"
  numactl="numactl --preferred=1"
fi

# @click.option('-x', '--repeats', default=3,
# help='Number of test case repetitions')
nruns=3

# click.option('-t', '--tn', default=250,
# help='End time of the simulation in ms'),
simulation_end_time=1000

# bench(problem, **kwargs): Complete benchmark with multiple simulation and performance parameters.

cmd=<< EOC
  env \
  DEVITO_PLATFORM=$plat \
  DEVITO_ISA=avx512 \
  DEVITO_DEBUG_COMPILER=1 \
  DEVITO_DLE_OPTIONS=blockinner:True \
  DEVITO_AUTOTUNING=aggressive \
  DEVITO_BACKEND=$backend \
  DEVITO_OPENMP=1 \
  DEVITO_ARCH=intel \
  DEVITO_LOGGING=DEBUG \
  DEVITO_YASK_AUTOTUNING=preemptive \
  DEVITO_YASK_DUMP=$dir \
  $numactl \
  python \
  examples/seismic/benchmark.py \
  bench \
  --bench-mode $bench_mode \
  --problem $problem \
  --space-order $space_order \
  --time-order 2 \
  --shape $grid_shape_ajusted $grid_shape_ajusted $grid_shape_ajusted \
  --tn $simulation_end_time \
  --repeats $nruns \
  --resultsdir $dir
EOC

echo $cmd >> $log
$cmd |& tee -a $log
date >> $log

done
done
done
done
done
