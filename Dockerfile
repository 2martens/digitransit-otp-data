ARG OTP_VERSION=1adb2ef64a0e6bb6d4aa0d1010f286354899122b
FROM mfdz/opentripplanner:$OTP_VERSION AS otp

# defined empty, so we can access the arg as env later again
ARG OTP_VERSION
ENV ROUTER_NAME=sw
RUN apt-get update
RUN apt-get install --yes zip

RUN mkdir -p /opt/opentripplanner/build/$ROUTER_NAME/

# add build data
# NOTE: we're trying to use dockers caching here. add items in order of least to most frequent changes
ADD unterfranken-latest.osm.pbf /opt/opentripplanner/build/$ROUTER_NAME/
ADD regional-gtfs.zip /opt/opentripplanner/build/$ROUTER_NAME/
ADD router-config.json /opt/opentripplanner/build/$ROUTER_NAME/
ADD build-config.json /opt/opentripplanner/build/$ROUTER_NAME/

# print version
RUN java -jar otp-shaded.jar --version | tee build/version.txt
RUN echo "image: mfdz/opentripplanner:$OTP_VERSION" >> build/version.txt

# build
RUN java -Xmx31G -jar otp-shaded.jar --build build/$ROUTER_NAME | tee build/build.log

# package: graph and config into zip
RUN sh -c 'cd /opt/opentripplanner/build/; export VERSION=$(grep "version:" version.txt | cut -d" " -f2); zip graph-$ROUTER_NAME-$VERSION.zip $ROUTER_NAME/Graph.obj $ROUTER_NAME/router-*.json'

RUN rm -rf /opt/opentripplanner/build/$ROUTER_NAME

# ---

FROM nginx:alpine

RUN sed -i 'N; s/index  index.html index.htm;/autoindex on;/' /etc/nginx/conf.d/default.conf; \
    sed -i '/error_page/d' /etc/nginx/conf.d/default.conf
RUN rm /usr/share/nginx/html/*.html

COPY --from=otp /opt/opentripplanner/build/ /usr/share/nginx/html/
