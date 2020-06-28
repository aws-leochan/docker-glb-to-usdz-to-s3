FROM python:2-slim-buster
LABEL maintainer="Leo Chan <leochan@amazon.com>"

# ---------------------------------------------------------------------
# Build + install usd
WORKDIR /usr/src/usd

# Configuration
ARG USD_RELEASE="20.05"
ARG USD_INSTALL="/usr/local/usd"
ENV PYTHONPATH="${PYTHONPATH}:${USD_INSTALL}/lib/python"
ENV PATH="${PATH}:${USD_INSTALL}/bin"

# Dependencies
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
    git build-essential cmake nasm \
    libglew-dev libxrandr-dev libxcursor-dev libxinerama-dev libxi-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Build + install USD
RUN git clone --branch "v${USD_RELEASE}" --depth 1 https://github.com/PixarAnimationStudios/USD.git /usr/src/usd
RUN python ./build_scripts/build_usd.py -v --no-usdview "${USD_INSTALL}" && \
  rm -rf "${USD_REPO}" "${USD_INSTALL}/build" "${USD_INSTALL}/src"

# ---------------------------------------------------------------------
# Build + install usd_from_gltf
WORKDIR /usr/src/ufg

# Configuration
ARG UFG_RELEASE="3bf441e0eb5b6cfbe487bbf1e2b42b7447c43d02"
ARG UFG_SRC="/usr/src/ufg"
ARG UFG_INSTALL="/usr/local/ufg"
ENV LD_LIBRARY_PATH="${USD_INSTALL}/lib:${UFG_SRC}/lib"
ENV PATH="${PATH}:${UFG_INSTALL}/bin"
ENV PYTHONPATH="${PYTHONPATH}:${UFG_INSTALL}/python"

RUN git init && \
    git remote add origin https://github.com/google/usd_from_gltf.git && \
    git fetch --depth 1 origin "${UFG_RELEASE}" && \
    git checkout FETCH_HEAD && \
    python "${UFG_SRC}/tools/ufginstall/ufginstall.py" -v "${UFG_INSTALL}" "${USD_INSTALL}" && \
    cp -r "${UFG_SRC}/tools/ufgbatch" "${UFG_INSTALL}/python" && \
    rm -rf "${UFG_SRC}" "${UFG_INSTALL}/build" "${UFG_INSTALL}/src"

RUN mkdir /usr/app
WORKDIR /usr/app

# ---------------------------------------------------------------------
# install the aws cli
RUN apt-get update && \
    apt-get install python-dev python-pip -y && \
    apt-get clean

RUN pip install awscli


# copy file from s3, convert, then upload coverted usdz to s3
ENTRYPOINT \
    localGlbFile=$(basename $INPUT_GLB_S3_FILEPATH) && \
    echo "Copying s3://${INPUT_GLB_S3_FILEPATH} to local $localGlbFile ..."  && \
    aws s3 cp s3://${INPUT_GLB_S3_FILEPATH} $localGlbFile && \
    echo "Converting $localGlbFile to ${OUTPUT_USDZ_FILE} ..." && \
    usd_from_gltf $localGlbFile ${OUTPUT_USDZ_FILE} && \
    echo "Copying ${OUTPUT_USDZ_FILE} to s3://${OUTPUT_S3_PATH}/${OUTPUT_USDZ_FILE} ..." && \
    aws s3 cp ./${OUTPUT_USDZ_FILE} s3://${OUTPUT_S3_PATH}/${OUTPUT_USDZ_FILE} --region ${AWS_REGION}

# Example for local testing:
# docker run -e INPUT_GLB_S3_FILEPATH='myBucket/myS3Dir/myModel.glb' \
#   -e OUTPUT_USDZ_FILE='myModel.usdz' \
#   -e OUTPUT_S3_PATH='myBucket/myS3Dir' \
#   -e AWS_REGION='us-west-2' \
#   -e AWS_ACCESS_KEY_ID='<your-access-key>' \
#   -e AWS_SECRET_ACCESS_KEY='<your-secret-key>' \
#   -it --rm awsleochan/docker-glb-to-usdz-to-s3
