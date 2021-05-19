FROM ubuntu:20.04

RUN apt update -y
RUN apt install -y build-essential curl

CMD bash
