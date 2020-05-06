# Since USD takes so long to build, we separate it into it's own container
FROM leon/usd:latest
LABEL maintainer="Leo Chan <leochan@amazon.com>"

# ---------------------------------------------------------------------
# install the aws cli
RUN apt-get update && \
    apt-get install python-dev python-pip -y && \
    apt-get clean

RUN pip install awscli

# ---------------------------------------------------------------------
# Build + install usd_from_gltf
# based on https://github.com/leon/docker-gltf-to-udsz/blob/master/usd-from-gltf/Dockerfile
WORKDIR /usr/src/ufg

# Configuration
ARG UFG_RELEASE="3bf441e0eb5b6cfbe487bbf1e2b42b7447c43d02"
ARG UFG_SRC="/usr/src/ufg"
ARG UFG_INSTALL="/usr/local/ufg"
ENV USD_DIR="/usr/local/usd"
ENV LD_LIBRARY_PATH="${USD_DIR}/lib:${UFG_SRC}/lib"
ENV PATH="${PATH}:${UFG_INSTALL}/bin"
ENV PYTHONPATH="${PYTHONPATH}:${UFG_INSTALL}/python"

RUN git init && \
    git remote add origin https://github.com/google/usd_from_gltf.git && \
    git fetch --depth 1 origin "${UFG_RELEASE}" && \
    git checkout FETCH_HEAD && \
    python "${UFG_SRC}/tools/ufginstall/ufginstall.py" -v "${UFG_INSTALL}" "${USD_DIR}" && \
    cp -r "${UFG_SRC}/tools/ufgbatch" "${UFG_INSTALL}/python" && \
    rm -rf "${UFG_SRC}" "${UFG_INSTALL}/build" "${UFG_INSTALL}/src"

RUN mkdir /usr/app
WORKDIR /usr/app

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
# docker run -e INPUT_GLB_S3_FILEPATH='myS3Bucket/myS3Folder/myModel.glb' \
#   -e OUTPUT_USDZ_FILE='myModel.usdz' \
#   -e OUTPUT_S3_PATH='myS3Bucket/myS3Folder' \
#   -e AWS_REGION='us-west-2' \
#   -e AWS_ACCESS_KEY_ID='<your-access-key>' \
#   -e AWS_SECRET_ACCESS_KEY='<your-secret-key>' \
#   -it --rm awsleochan/docker-glb-to-usdz-to-s3

