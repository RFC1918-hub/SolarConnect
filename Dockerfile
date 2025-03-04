ARG BUILD_FROM
FROM $BUILD_FROM

# Install required packages
RUN apk add --no-cache mosquitto-clients bash

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]