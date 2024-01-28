
# diun.platform=linux/arm64
FROM semaphoreui/semaphore:latest@sha256:47add7dba5172f9709cc251b36cbda187ca60b97bc417ce68cb182aa3e400346

USER root
RUN apk add --no-cache python3 py3-pip
RUN pip install pywinrm jmespath netaddr passlib requests matrix_client

USER semaphore
