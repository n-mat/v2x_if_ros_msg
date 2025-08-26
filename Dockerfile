ARG PROJECT




FROM ros:noetic-ros-core-focal AS v2x_if_ros_msg_requirements_base

ARG PROJECT
ARG REQUIREMENTS_FILE="requirements.${PROJECT}.ubuntu20.04.system"

# Step 0: Allow insecure repos temporarily
RUN echo 'Acquire::AllowInsecureRepositories "true";' > /etc/apt/apt.conf.d/99insecure && \
    echo 'Acquire::Check-Valid-Until "false";' >> /etc/apt/apt.conf.d/99insecure

# Step 1: Install curl, gnupg2, etc.
RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg2 ca-certificates

# Step 2: Replace the expired key (used by ROS repo already present in base image)
RUN curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | \
    gpg --dearmor --no-tty --batch --yes -o /usr/share/keyrings/ros1-latest-archive-keyring.gpg


# Step 3: Remove insecure workaround
RUN rm /etc/apt/apt.conf.d/99insecure

# Step 4: Setup build env
RUN mkdir -p /tmp/${PROJECT}
WORKDIR /tmp/${PROJECT}
COPY files/${REQUIREMENTS_FILE} /tmp/${PROJECT}
RUN apt-get update && \
    xargs apt-get install --no-install-recommends -y < ${REQUIREMENTS_FILE} && \
    rm -rf /var/lib/apt/lists/*

# Copy code
COPY ${PROJECT} /tmp/${PROJECT}/${PROJECT}
COPY files/catkin_build.sh /tmp/${PROJECT}/${PROJECT}


FROM v2x_if_ros_msg_requirements_base AS v2x_if_ros_msg_builder
ARG PROJECT
WORKDIR /tmp/${PROJECT}/${PROJECT}
RUN mkdir -p build 
SHELL ["/bin/bash", "-c"]
WORKDIR /tmp/${PROJECT}/${PROJECT}/build

RUN source /opt/ros/noetic/setup.bash && \
    cmake .. && \
    cmake --build . --config Release --target install -- -j $(nproc) && \
    cpack -G DEB && find . -type f -name "*.deb" | xargs mv -t . && \
    cd /tmp/${PROJECT}/${PROJECT}/build && ln -s devel install && \
    mv CMakeCache.txt CMakeCache.txt.build
#RUN bash catkin_build.sh

FROM alpine:3.14

ARG PROJECT
#COPY --from=v2x_if_ros_msg_builder /tmp/${PROJECT}/build /tmp/${PROJECT}/build
COPY --from=v2x_if_ros_msg_builder /tmp/${PROJECT}/${PROJECT} /tmp/${PROJECT}/${PROJECT}

