FROM python:3.6

RUN apt-get update && apt-get install -y -q \ 
    mpich \ 
    libmpich-dev 

ADD ./devito/requirements.txt /app/requirements.txt

RUN python3 -m venv /venv && \
    /venv/bin/pip install --no-cache-dir --upgrade pip && \
    /venv/bin/pip install --no-cache-dir jupyter && \
    /venv/bin/pip install --no-cache-dir -r /app/requirements.txt

ADD ./devito/devito /app/devito
ADD ./devito/tests /app/tests
ADD ./devito/examples /app/examples

ADD ./devito/docker/run-jupyter.sh /jupyter
ADD ./devito/docker/run-tests.sh /tests
ADD ./devito/docker/run-print-defaults.sh /print-defaults
ADD ./devito/docker/entrypoint.sh /docker-entrypoint.sh
ADD ./run.sh /app/run.sh
ADD ./benchmark-backends.sh /app/benchmark-backends.sh

RUN chmod +x \
    /print-defaults \
    /jupyter \
    /tests \
    /docker-entrypoint.sh \
    /app/run.sh
    /app/benchmark-backends.sh

WORKDIR /app

ENV DEVITO_ARCH="gcc"
ENV DEVITO_OPENMP="0"


EXPOSE 8888
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bash"]
