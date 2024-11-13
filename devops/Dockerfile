FROM ubuntu:20.04

ARG ACCESS_KEY
ARG SECRET_KEY
ARG REGION

ENV AWS_ACCESS_KEY=$ACCESS_KEY
ENV AWS_SECRET_ACCESS_KEY=$SECRET_KEY
ENV AWS_DEFAULT_REGION=$REGION

WORKDIR /workspace 
COPY . /workspace/
RUN apt-get update && apt-get install -y sudo
RUN bash -c "./provision.sh"
RUN bash -c "./configure-aws.sh"

CMD ["/bin/bash"]