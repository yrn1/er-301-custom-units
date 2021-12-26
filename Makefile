# top-level makefile

PROJECTS = fdelay yutil

docker_image = er-301-am335x-build-env

all: $(PROJECTS)

asm: $(addsuffix -asm,$(PROJECTS))

$(PROJECTS):
	+$(MAKE) -f src/mods/$@/mod.mk PKGNAME=$@

$(addsuffix -emu,$(PROJECTS)): $(@:-emu=)
	$(eval PROJECT := $(@:-emu=))
	+$(MAKE) -f src/mods/$(PROJECT)/mod.mk emu PKGNAME=$(PROJECT)

$(addsuffix -install,$(PROJECTS)): $(@:-install=)
	$(eval PROJECT := $(@:-install=))
	+$(MAKE) -f src/mods/$(PROJECT)/mod.mk install PKGNAME=$(PROJECT)

$(addsuffix -install-sd,$(PROJECTS)):
	$(eval PROJECT := $(@:-install-sd=))
	+$(MAKE) -f src/mods/$(PROJECT)/mod.mk install-sd PKGNAME=$(PROJECT) ARCH=am335x PROFILE=release

$(addsuffix -install-sd-testing,$(PROJECTS)):
	$(eval PROJECT := $(@:-install-sd-testing=))
	+$(MAKE) -f src/mods/$(PROJECT)/mod.mk install-sd PKGNAME=$(PROJECT) ARCH=am335x PROFILE=testing

$(addsuffix -missing,$(PROJECTS)):
	$(eval PROJECT := $(@:-missing=))
	+$(MAKE) -f src/mods/$(PROJECT)/mod.mk missing PKGNAME=$(PROJECT)

$(addsuffix -asm,$(PROJECTS)):
	$(eval PROJECT := $(@:-asm=))
	+$(MAKE) -f src/mods/$(PROJECT)/mod.mk asm PKGNAME=$(PROJECT)

$(addsuffix -list,$(PROJECTS)):
	$(eval PROJECT := $(@:-list=))
	+$(MAKE) -f src/mods/$(PROJECT)/mod.mk list PKGNAME=$(PROJECT)

am335x-docker:
	docker build docker/er-301-am335x-build-env/ -t er-301-am335x-build-env --platform=linux/amd64

release:
	docker run --rm -it -v `pwd`:/er-301-custom-units -w /er-301-custom-units --platform=linux/amd64 $(docker_image)  \
		make -j 4 all ARCH=am335x PROFILE=release

testing:
	docker run --rm -it -v `pwd`:/er-301-custom-units -w /er-301-custom-units --platform=linux/amd64 $(docker_image) \
		make -j 4 all ARCH=am335x PROFILE=testing

release-asm:
	docker run --rm -it -v `pwd`:/er-301-custom-units -w /er-301-custom-units --platform=linux/amd64 $(docker_image) \
		make -j asm ARCH=am335x PROFILE=release

er-301-docker:
	docker run --rm --privileged -it -v `pwd`:/er-301-custom-units -w /er-301-custom-units/er-301 --platform=linux/amd64 $(docker_image) \
		make -j 4 ARCH=am335x PROFILE=release

er-301-docker-testing:
	docker run --rm --privileged -it -v `pwd`:/er-301-custom-units -w /er-301-custom-units/er-301 --platform=linux/amd64 $(docker_image) \
		make -j 4 ARCH=am335x PROFILE=testing

release-missing:
	docker run --rm -it -v `pwd`:/er-301-custom-units -w /er-301-custom-units --platform=linux/amd64 $(docker_image) \
		make -j 4 strike-missing ARCH=am335x PROFILE=release

clean:
	rm -rf testing debug release

.PHONY: all clean $(PROJECTS) $(addsuffix -install,$(PROJECTS)) $(addsuffix -install-sd,$(PROJECTS)) $(addsuffix -install-sd-testing,$(PROJECTS)) $(addsuffix -missing,$(PROJECTS)) am335x-docker release testing er-301-docker release-missing clean
