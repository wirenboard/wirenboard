Jenkins pipelines
=================

This directory contains pipeline descriptions for various Jenkins jobs
related with devenv, image building etc.

Corresponding jobs are stored in Jenkins in pipelines/ folder.


buildImage.groovy
-----------------

This pipeline builds images (fit, img) with rootfs for different boards.
Main WB repository and additional experimental repos are configurable.

See pipelines/build-image job for some more details.


publishImage.groovy
-------------------

This pipeline takes firmware images from pipelines/build-image build
and publishes them on Amazon S3 cloud to make them available for users.

See pipelines/publish-image job for some more details.


checkStaging.groovy
-------------------

This pipeline checks current staging repository consistency by building firmware images
for devices which can run staging. If checks are successful, unstable repository updates
to current staging.

wirenboard/wb-releases triggers this job, so it runs when new packages are added to staging.

Image building is pretty time-consuming. To avoid unnecessary builds, this pipeline checks
if unstable and staging are not the same before proceed.

See pipelines/check-staging job for some more details.


releaseImages.groovy
--------------------

This pipeline triggers pipelines/build-image job to build stable images
and then triggers pipelines/publish-image job to publish these images.

wirenboard/wb-releases schedules this job if releases.yaml is changed, so
new images are published automatically when our packages are updated.

See pipelines/release-images job for some more details.


TODO
====

  * pipeline in this repository which (re-)creates jobs with these pipelines
    (may be used to fill in empty Jenkins installation).
