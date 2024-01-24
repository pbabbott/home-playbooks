FROM semaphoreui/semaphore:latest@sha256:5dd25a8ab67b31e557efb96722a9d3166526930c3463ff8c7df914f254a957ee

USER root
RUN apk add --no-cache python3 py3-pip
RUN pip install pywinrm jmespath netaddr passlib requests matrix_client

USER semaphore
