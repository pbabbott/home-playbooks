FROM semaphoreui/semaphore:latest

USER root
RUN /sbin/apk add py3-pip

USER semaphore
RUN pip3 install --user pywinrm

COPY requirements.txt /home/semaphore/requirements.txt
