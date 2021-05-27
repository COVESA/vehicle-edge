FROM python:3.6.12 as build

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG IOTEA_PYTHON_SDK

ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}

RUN mkdir /build

COPY iot-event-analytics /build/iot-event-analytics

WORKDIR /build/iot-event-analytics/src/sdk/python

# Build and install IoT Event Analytics Python SDK from source
RUN python -m pip install ./src --user

WORKDIR /build

COPY ./src/edge.hal-interface/requirements.txt .

# Install application requirements
RUN python -m pip install -r requirements.txt --user

FROM python:3.6.12-alpine

# Copy all required packages into this image
COPY --from=build /root/.local/lib/python3.6/site-packages /root/.local/lib/python3.6/site-packages

RUN mkdir /app

WORKDIR /app

COPY ./src/edge.hal-interface/src/* ./

CMD [ "python", "run.py" ]