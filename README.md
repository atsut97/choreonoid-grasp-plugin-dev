# Docker Grasp Plugin

Utility to create development environment for Grasp Plugin.

## What is Grasp Plugin?

Grasp Plugin is a plugin designed for an integrated robot simulator
[Choreonoid](https://choreonoid.org) which provides grasp planning
algorigthms for multi-fingered robotic hands. It was originally
developed by Tokuo Tsuji and Kensuke Harada, and is being maintained
and actively developed by [Kensuke Harada and his
colleagues](https://www.roboticmanipulation.org/).

This repository contains Dockerfiles to develop Grasp Plugin and
a utility script to build Docker images and run a container.

## Usage

Let's say we will build Choreonoid that points to v1.7.0 with Grasp
Plugin enabled on Ubuntu 18.04 and Ubuntu 20.04, respectively.

First you can clone this repository with the following command:

``` shell
git clone https://github.com/atsut97/choreonoid-grasp-plugin-dev.git
```

If you add `--recursive` option,
[graspPlugin](https://github.com/kensuke-harada/graspPlugin) will be
 also synchronized as a submodule.

``` shell
git clone --recursive https://github.com/atsut97/choreonoid-grasp-plugin-dev.git
```

If you have a forked graspPlugin repository of your own, you can change the
remote of the submodule to it. To do this you should edit
`.gitmodule` in the root directory first to specify a different
graspPlugin repository.

``` diff
[submodule "graspPlugin"]
        path = graspPlugin
-       url = https://github.com/kensuke-harada/graspPlugin
+       url = https://github.com/atsut97/graspPlugin
```

Then type the following commands to synchronize:

``` shell
cd choreonoid-grasp-plugin-dev
git submodule sync
git submodule update
```

There are several choices and preferences to develop software with
Docker. As far as I can come up with, the following three ways are
feasible to include the source code into a Docker container:

  1. Add an instruction to download from a remote the source when
     building an image.
  2. Add an instruction to copy from the host machine when building an
     image.
  3. Mount a directory on the host machine that contains the source
     code into a container when running it.

The first choice is thought to be the best after the development is
done and it's ready to release. The second could be an option when the
environment and build dependencies are completely fixed. The last one
is very handy if you need to let the software in development be built
in more than one environment.

In our case, mounting the source code directory into a container is
suitable. You can use the following commands to build a Docker image
based on a Dockerfile contained in this repository:

``` shell
docker build --tag grasp-plugin:1.7-bionic --file $(pwd)/bionic/Dockerfile --build-arg CHOREONOID_TAG=v1.7.0 $(pwd)
docker run -it -v $(pwd)/graspPlugin:/opt/choreonoid/ext/graspPlugin grasp-plugin:1.7-bionic /bin/bash
```

This time we will build the Grasp Plugin on Ubuntu 20.04 as well. To
do this, run the following commands:

``` shell
docker build --tag grasp-plugin:1.7-focal --file $(pwd)/focal/Dockerfile --build-arg CHOREONOID_TAG=v1.7.0 $(pwd)
docker run -it -v $(pwd)/graspPlugin:/opt/choreonoid/ext/graspPlugin grasp-plugin:1.7-focal /bin/bash
```

## Contributing

Pull requests are welcome.

## License

[MIT](https://choosealicense.com/licenses/mit/)
