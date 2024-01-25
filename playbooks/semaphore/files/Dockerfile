
# diun.platform=linux/arm64
FROM semaphoreui/semaphore:latest@sha256:5dd25a8ab67b31e557efb96722a9d3166526930c3463ff8c7df914f254a957ee

USER root
RUN apk add --no-cache python3 py3-pip
RUN pip install pywinrm jmespath netaddr passlib requests matrix_client

# Issue where docker system prune is not working against room_of_requirement
# https://github.com/docker/docker-py/issues/3113#issuecomment-1531621678
RUN pip remove requests && pip install requests=2.28.1

USER semaphore
