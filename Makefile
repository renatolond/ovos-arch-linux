.PHONY: all clean extra repo create-repo sync-repo aur-repo rebuild uninstall
# MODE := "source"
ARCH := $(shell if [ -n "$$ARCH" ]; then echo "$$ARCH"; else uname -m; fi)
WORKSPACE_DIR := $(shell pwd)
REPO_ROOT := $(WORKSPACE_DIR)/.repo
REPO_DIR := $(REPO_ROOT)/$(ARCH)
PACMAN_CONF := $(REPO_ROOT)/pacman-$(ARCH).conf

ifneq (, $(ONLINE_REPO_URI))
	REPO_URI := "$(ONLINE_REPO_URI)/$(ARCH)"
else
	REPO_URI := "file:///$(REPO_DIR)"
endif

ifeq ($(MODE), repo)
	RUN_MAKEPKG := "$(WORKSPACE_DIR)/tools/pkg-build/repo-build.sh" "$(REPO_DIR)" "$(REPO_ROOT)/pacman-wrapper-$(ARCH).sh"
else 
	RUN_MAKEPKG := "$(WORKSPACE_DIR)/tools/pkg-build/source-build.sh"
endif

OVOS_PACKAGES := $(notdir $(wildcard PKGBUILDs/*))
EXTRA_PACKAGES := $(notdir $(wildcard PKGBUILDs-extra/*))
ALL_PACKAGES := $(OVOS_PACKAGES) + $(EXTRA_PACKAGES)

# The default target will build all OVOS packages and only those 'extra' dependent packages which are in use
all: $(OVOS_PACKAGES)

extra: $(EXTRA_PACKAGES)

clean: rebuild
	@rm -rf ./{PKGBUILDs,PKGBUILDs-extra}/*/{pkg,src}
rebuild:
	@echo 'Deleted any built packages, you may now run make all'
	@rm -rf ./{PKGBUILDs,PKGBUILDs-extra}/*/*.pkg.tar* $(REPO_DIR)

uninstall:
	@pacman -Qq | sort | comm -12 - <(echo "$(ALL_PACKAGES)" | tr ' ' '\n' | sort) | xargs sudo pacman -Rcns --noconfirm

repo: create-repo aur-repo
	@echo "All architecure repos created..."

create-repo:
	@mkdir -p "$(REPO_DIR)/"
	@if [ ! -f "$(REPO_DIR)/ovos-arch.db.tar.gz" ]; then \
		if [ "$(INPUT_REBUILDALL)" != 1 ] && [ -n "$(ONLINE_REPO_URI)" ] ; then \
			wget "$(ONLINE_REPO_URI)/$(ARCH)/ovos-arch.db" -O "$(REPO_DIR)/ovos-arch.db"; \
			wget "$(ONLINE_REPO_URI)/$(ARCH)/ovos-arch.db.tar.gz" -O "$(REPO_DIR)/ovos-arch.db.tar.gz"; \
			if [ $(ARCH) = "x86_64" ] ; then \
				mkdir -p "$(REPO_DIR)/../aarch64/"; \
				wget "$(ONLINE_REPO_URI)/aarch64/ovos-arch.db" -O "$(REPO_DIR)/../aarch64/ovos-arch.db"; \
				wget "$(ONLINE_REPO_URI)/aarch64/ovos-arch.db.tar.gz" -O "$(REPO_DIR)/../aarch64/ovos-arch.db.tar.gz"; \
				mkdir -p "$(REPO_DIR)/../armv7h/"; \
				wget "$(ONLINE_REPO_URI)/armv7h/ovos-arch.db" -O "$(REPO_DIR)/../armv7h/ovos-arch.db"; \
				wget "$(ONLINE_REPO_URI)/armv7h/ovos-arch.db.tar.gz" -O "$(REPO_DIR)/../armv7h/ovos-arch.db.tar.gz"; \
			fi; \
		else \
			repo-add "$(REPO_DIR)/ovos-arch.db.tar.gz"; \
			echo "Repo created..."; \
		fi; \
	fi
	@cp /etc/pacman.conf "$(PACMAN_CONF)"
	@printf "\n\n[ovos-arch]\nSigLevel = Optional TrustAll\nServer = $(REPO_URI)" >> $(PACMAN_CONF)
	@if [ -n "$(PACKAGE_CACHE_URI)" ] ; then \
		sed -i 's|Include\s*=\s*/etc/pacman.d/mirrorlist|Server = $(PACKAGE_CACHE_URI)/\$$repo/os/\$$arch|' "$(PACMAN_CONF)"; \
	fi
	@cp "$(WORKSPACE_DIR)/tools/pkg-build/pacman-wrapper.sh" "$(REPO_ROOT)/pacman-wrapper-$(ARCH).sh"
	@sed -i 's|/etc/pacman.conf|$(PACMAN_CONF)|g' "$(REPO_ROOT)/pacman-wrapper-$(ARCH).sh"
	@chmod +x "$(REPO_ROOT)/pacman-wrapper-$(ARCH).sh"

sync-repo:
	@"$(REPO_ROOT)/pacman-wrapper-$(ARCH).sh" -Syy 

aur-repo:
	@mkdir -p "$(WORKSPACE_DIR)/AUR"
	./tools/aur-repo.sh "$(WORKSPACE_DIR)/AUR/" "$(WORKSPACE_DIR)/aur.lock"

%.pkg.tar.xz:
	$(eval DIR := $(shell echo '$*' | cut -d* -f1))
	@echo "Building $(DIR) with ''$(RUN_MAKEPKG)''"
	@cd $(DIR) && $(RUN_MAKEPKG)
	
mycroft-gui-qt5:  PKGBUILDs/mycroft-gui-qt5/*.pkg.tar.xz

mycroft-mimic1:  PKGBUILDs/mycroft-mimic1/*.pkg.tar.xz

mycroft-mimic1-voices:  PKGBUILDs/mycroft-mimic1/*.pkg.tar.xz

mycroft-mimic3-tts-bin:  PKGBUILDs/mycroft-mimic3-tts-bin/*.pkg.tar.xz

nsync:  PKGBUILDs-extra/nsync/*.pkg.tar.xz

onnxruntime: nsync PKGBUILDs-extra/onnxruntime/*.pkg.tar.xz

ovos-bus-server: ovos-service-base PKGBUILDs/ovos-bus-server/*.pkg.tar.xz

ovos-core: python-ovos-core python-ovos-messagebus PKGBUILDs/ovos-core/*.pkg.tar.xz

ovos-dashboard:  PKGBUILDs/ovos-dashboard/*.pkg.tar.xz

ovos-enclosure-audio-pulse:  PKGBUILDs/ovos-enclosure-audio-pulse/*.pkg.tar.xz

ovos-enclosure-audio-vocalfusion-dkms:  PKGBUILDs/ovos-enclosure-audio-vocalfusion-dkms/*.pkg.tar.xz

ovos-enclosure-base: ovos-core ovos-shell-standalone python-ovos-messagebus python-ovos-dinkum-listener python-ovos-gui python-ovos-phal python-ovos-audio python-ovos-core python-ovos-tts-plugin-mimic python-ovos-tts-plugin-mimic3-server ovos-skill-official-homescreen ovos-skill-official-naptime ovos-skill-official-date-time ovos-skill-official-volume ovos-skill-official-fallback-unknown PKGBUILDs/ovos-enclosure-base/*.pkg.tar.xz

ovos-enclosure-rpi4-mark2: ovos-enclosure-base ovos-enclosure-sj201 ovos-enclosure-audio-pulse PKGBUILDs/ovos-enclosure-rpi4-mark2/*.pkg.tar.xz

ovos-enclosure-sj201: ovos-enclosure-audio-vocalfusion-dkms python-spidev python-rpi.gpio python-smbus2 PKGBUILDs/ovos-enclosure-sj201/*.pkg.tar.xz

ovos-precise-lite-models:  PKGBUILDs/ovos-precise-lite-models/*.pkg.tar.xz

ovos-service-base:  PKGBUILDs/ovos-service-base/*.pkg.tar.xz

ovos-shell: mycroft-gui-qt5 python-ovos-gui-plugin-shell-companion python-ovos-phal-plugin-alsa python-ovos-phal-plugin-system PKGBUILDs/ovos-shell/*.pkg.tar.xz

ovos-shell-standalone: ovos-service-base ovos-shell PKGBUILDs/ovos-shell-standalone/*.pkg.tar.xz

ovos-skill-neon-local-music: python-ovos-ocp-audio-plugin python-ovos-ocp-files-plugin python-ovos-skill-installer python-ovos-utils python-ovos-workshop PKGBUILDs/ovos-skill-neon-local-music/*.pkg.tar.xz

ovos-skill-official-camera: python-ovos-utils python-ovos-workshop PKGBUILDs/ovos-skill-official-camera/*.pkg.tar.xz

ovos-skill-official-date-time: python-ovos-workshop python-ovos-utils python-timezonefinder python-tzlocal PKGBUILDs/ovos-skill-official-date-time/*.pkg.tar.xz

ovos-skill-official-fallback-unknown: python-ovos-utils python-ovos-workshop PKGBUILDs/ovos-skill-official-fallback-unknown/*.pkg.tar.xz

ovos-skill-official-homescreen: python-ovos-utils python-ovos-workshop python-ovos-lingua-franca python-ovos-phal-plugin-wallpaper-manager python-ovos-skill-manager PKGBUILDs/ovos-skill-official-homescreen/*.pkg.tar.xz

ovos-skill-official-naptime: python-ovos-workshop python-ovos-bus-client python-ovos-utils PKGBUILDs/ovos-skill-official-naptime/*.pkg.tar.xz

ovos-skill-official-news: python-ovos-ocp-audio-plugin python-ovos-workshop PKGBUILDs/ovos-skill-official-news/*.pkg.tar.xz

ovos-skill-official-setup: python-ovos-backend-client python-ovos-utils python-ovos-workshop python-ovos-phal-plugin-system python-ovos-plugin-manager PKGBUILDs/ovos-skill-official-setup/*.pkg.tar.xz

ovos-skill-official-stop: python-ovos-workshop python-ovos-utils PKGBUILDs/ovos-skill-official-stop/*.pkg.tar.xz

ovos-skill-official-volume: python-ovos-utils PKGBUILDs/ovos-skill-official-volume/*.pkg.tar.xz

ovos-skill-official-weather: python-ovos-workshop python-ovos-utils PKGBUILDs/ovos-skill-official-weather/*.pkg.tar.xz

ovos-skill-official-youtube-music: python-ovos-ocp-youtube-plugin python-ovos-utils python-ovos-workshop python-tutubo PKGBUILDs/ovos-skill-official-youtube-music/*.pkg.tar.xz

ovos-splash:  PKGBUILDs/ovos-splash/*.pkg.tar.xz

python-adapt-parser:  PKGBUILDs-extra/python-adapt-parser/*.pkg.tar.xz

python-bitstruct:  PKGBUILDs-extra/python-bitstruct/*.pkg.tar.xz

python-bs4:  PKGBUILDs-extra/python-bs4/*.pkg.tar.xz

python-combo-lock: python-filelock python-memory-tempfile PKGBUILDs-extra/python-combo-lock/*.pkg.tar.xz

python-convertdate: aur-repo AUR/python-convertdate/*.pkg.tar.xz

python-crfsuite-git:  PKGBUILDs-extra/python-crfsuite-git/*.pkg.tar.xz

python-cutecharts:  PKGBUILDs-extra/python-cutecharts/*.pkg.tar.xz

python-dataclasses-json: aur-repo python-marshmallow-enum AUR/python-dataclasses-json/*.pkg.tar.xz

python-dateparser: aur-repo python-tzlocal python-convertdate python-hijri-converter AUR/python-dateparser/*.pkg.tar.xz

python-deezeridu:  PKGBUILDs-extra/python-deezeridu/*.pkg.tar.xz

python-epitran: aur-repo python-marisa-trie python-panphon AUR/python-epitran/*.pkg.tar.xz

python-espeak-phonemizer:  PKGBUILDs-extra/python-espeak-phonemizer/*.pkg.tar.xz

python-filelock:  PKGBUILDs-extra/python-filelock/*.pkg.tar.xz

python-gradio: python-pydub python-uvicorn PKGBUILDs-extra/python-gradio/*.pkg.tar.xz

python-gruut: python-dateparser python-gruut-ipa python-gruut-lang-en python-num2words python-crfsuite-git PKGBUILDs-extra/python-gruut/*.pkg.tar.xz

python-gruut-ipa: aur-repo AUR/python-gruut-ipa/*.pkg.tar.xz

python-gruut-lang-en: aur-repo AUR/python-gruut-lang-en/*.pkg.tar.xz

python-h3:  PKGBUILDs-extra/python-h3/*.pkg.tar.xz

python-hijri-converter: aur-repo AUR/python-hijri-converter/*.pkg.tar.xz

python-json-database: python-combo-lock PKGBUILDs-extra/python-json-database/*.pkg.tar.xz

python-kthread:  PKGBUILDs-extra/python-kthread/*.pkg.tar.xz

python-langcodes:  PKGBUILDs-extra/python-langcodes/*.pkg.tar.xz

python-marisa-trie: aur-repo AUR/python-marisa-trie/*.pkg.tar.xz

python-marshmallow-enum: aur-repo AUR/python-marshmallow-enum/*.pkg.tar.xz

python-memory-tempfile:  PKGBUILDs-extra/python-memory-tempfile/*.pkg.tar.xz

python-mycroft-messagebus-client:  PKGBUILDs/python-mycroft-messagebus-client/*.pkg.tar.xz

python-mycroft-mimic3-tts: python-espeak-phonemizer python-dataclasses-json python-epitran python-gruut python-onnxruntime python-phonemes2ids python-xdgenvpy PKGBUILDs/python-mycroft-mimic3-tts/*.pkg.tar.xz

python-nested-lookup:  PKGBUILDs-extra/python-nested-lookup/*.pkg.tar.xz

python-num2words: aur-repo AUR/python-num2words/*.pkg.tar.xz

python-onnxruntime: onnxruntime nsync PKGBUILDs-extra/onnxruntime/*.pkg.tar.xz

python-ovos-audio: ovos-core ovos-service-base python-ovos-messagebus python-sdnotify python-ovos-ocp-audio-plugin python-ovos-bus-client python-ovos-config python-ovos-ocp-files-plugin python-ovos-ocp-m3u-plugin python-ovos-ocp-news-plugin python-ovos-ocp-rss-plugin python-ovos-plugin-manager python-ovos-utils PKGBUILDs/python-ovos-audio/*.pkg.tar.xz

python-ovos-audio-plugin-simple: python-ovos-plugin-manager PKGBUILDs/python-ovos-audio-plugin-simple/*.pkg.tar.xz

python-ovos-backend-client: python-json-database python-ovos-config python-ovos-utils PKGBUILDs/python-ovos-backend-client/*.pkg.tar.xz

python-ovos-backend-manager: python-cutecharts python-ovos-personal-backend python-pywebio PKGBUILDs/python-ovos-backend-manager/*.pkg.tar.xz

python-ovos-bus-client: python-ovos-config python-ovos-utils PKGBUILDs/python-ovos-bus-client/*.pkg.tar.xz

python-ovos-classifiers: python-ovos-utils PKGBUILDs/python-ovos-classifiers/*.pkg.tar.xz

python-ovos-cli-client: python-ovos-utils python-ovos-bus-client PKGBUILDs/python-ovos-cli-client/*.pkg.tar.xz

python-ovos-config: python-combo-lock python-ovos-utils python-rich-click PKGBUILDs/python-ovos-config/*.pkg.tar.xz

python-ovos-config-assistant: python-cutecharts python-ovos-backend-client python-ovos-utils python-pywebio PKGBUILDs/python-ovos-config-assistant/*.pkg.tar.xz

python-ovos-core: ovos-service-base python-ovos-messagebus python-sdnotify python-adapt-parser python-combo-lock python-ovos-backend-client python-ovos-bus-client python-ovos-workshop python-ovos-classifiers python-ovos-config python-ovos-lingua-franca python-ovos-plugin-manager python-ovos-utils python-padacioso PKGBUILDs/python-ovos-core/*.pkg.tar.xz

python-ovos-dinkum-listener: ovos-core ovos-service-base python-ovos-messagebus python-sdnotify python-ovos-microphone-plugin-alsa python-ovos-backend-client python-ovos-bus-client python-ovos-config python-ovos-plugin-manager python-ovos-stt-plugin-server python-ovos-utils python-ovos-vad-plugin-webrtcvad python-speechrecognition PKGBUILDs/python-ovos-dinkum-listener/*.pkg.tar.xz

python-ovos-gui: ovos-core ovos-service-base python-ovos-messagebus python-sdnotify python-ovos-bus-client python-ovos-config python-ovos-plugin-manager python-ovos-utils PKGBUILDs/python-ovos-gui/*.pkg.tar.xz

python-ovos-gui-plugin-shell-companion: python-ovos-plugin-manager python-ovos-utils python-ovos-bus-client PKGBUILDs/python-ovos-gui-plugin-shell-companion/*.pkg.tar.xz

python-ovos-lingua-franca: python-quebra-frases PKGBUILDs/python-ovos-lingua-franca/*.pkg.tar.xz

python-ovos-listener: ovos-core ovos-service-base python-ovos-messagebus python-sdnotify python-ovos-backend-client python-ovos-bus-client python-ovos-config python-ovos-plugin-manager python-ovos-stt-plugin-server python-ovos-stt-plugin-vosk python-ovos-utils python-ovos-vad-plugin-webrtcvad python-ovos-ww-plugin-pocketsphinx python-ovos-ww-plugin-precise-lite python-ovos-ww-plugin-vosk python-speechrecognition PKGBUILDs/python-ovos-listener/*.pkg.tar.xz

python-ovos-messagebus: ovos-service-base python-sdnotify python-ovos-bus-client python-ovos-config python-ovos-utils PKGBUILDs/python-ovos-messagebus/*.pkg.tar.xz

python-ovos-microphone-plugin-alsa: python-ovos-plugin-manager python-pyalsaaudio PKGBUILDs/python-ovos-microphone-plugin-alsa/*.pkg.tar.xz

python-ovos-microphone-plugin-pyaudio: python-ovos-plugin-manager python-speechrecognition PKGBUILDs/python-ovos-microphone-plugin-pyaudio/*.pkg.tar.xz

python-ovos-microphone-plugin-sounddevice: python-ovos-plugin-manager python-speechrecognition PKGBUILDs/python-ovos-microphone-plugin-sounddevice/*.pkg.tar.xz

python-ovos-notifications-service: python-mycroft-messagebus-client python-ovos-utils PKGBUILDs/python-ovos-notifications-service/*.pkg.tar.xz

python-ovos-ocp-audio-plugin: python-ovos-bus-client python-ovos-ocp-files-plugin python-ovos-plugin-manager python-ovos-utils python-ovos-workshop python-padacioso PKGBUILDs/python-ovos-ocp-audio-plugin/*.pkg.tar.xz

python-ovos-ocp-bandcamp-plugin: python-ovos-ocp-audio-plugin python-py-bandcamp PKGBUILDs/python-ovos-ocp-bandcamp-plugin/*.pkg.tar.xz

python-ovos-ocp-deezer-plugin: python-deezeridu python-ovos-ocp-audio-plugin PKGBUILDs/python-ovos-ocp-deezer-plugin/*.pkg.tar.xz

python-ovos-ocp-files-plugin: python-bitstruct python-pprintpp PKGBUILDs/python-ovos-ocp-files-plugin/*.pkg.tar.xz

python-ovos-ocp-m3u-plugin: python-ovos-ocp-audio-plugin PKGBUILDs/python-ovos-ocp-m3u-plugin/*.pkg.tar.xz

python-ovos-ocp-news-plugin: python-ovos-ocp-audio-plugin python-ovos-ocp-m3u-plugin python-ovos-ocp-rss-plugin PKGBUILDs/python-ovos-ocp-news-plugin/*.pkg.tar.xz

python-ovos-ocp-rss-plugin: python-ovos-ocp-audio-plugin PKGBUILDs/python-ovos-ocp-rss-plugin/*.pkg.tar.xz

python-ovos-ocp-youtube-plugin: python-ovos-ocp-audio-plugin python-tutubo python-yt-dlp PKGBUILDs/python-ovos-ocp-youtube-plugin/*.pkg.tar.xz

python-ovos-personal-backend: python-json-database python-ovos-plugin-manager python-ovos-stt-plugin-server python-ovos-utils python-requests-cache python-sqlalchemy-json python-timezonefinder PKGBUILDs/python-ovos-personal-backend/*.pkg.tar.xz

python-ovos-phal: ovos-core ovos-service-base python-ovos-messagebus python-sdnotify python-ovos-workshop python-ovos-bus-client python-ovos-config python-ovos-phal-plugin-connectivity-events python-ovos-phal-plugin-ipgeo python-ovos-phal-plugin-network-manager python-ovos-phal-plugin-oauth python-ovos-phal-plugin-system python-ovos-plugin-manager python-ovos-utils PKGBUILDs/python-ovos-phal/*.pkg.tar.xz

python-ovos-phal-plugin-alsa: python-json-database python-ovos-bus-client python-ovos-plugin-manager python-pyalsaaudio PKGBUILDs/python-ovos-phal-plugin-alsa/*.pkg.tar.xz

python-ovos-phal-plugin-balena-wifi: python-mycroft-messagebus-client python-ovos-utils python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-balena-wifi/*.pkg.tar.xz

python-ovos-phal-plugin-brightness-control-rpi: python-mycroft-messagebus-client python-ovos-utils python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-brightness-control-rpi/*.pkg.tar.xz

python-ovos-phal-plugin-color-scheme-manager: python-mycroft-messagebus-client python-ovos-utils python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-color-scheme-manager/*.pkg.tar.xz

python-ovos-phal-plugin-configuration-provider: python-mycroft-messagebus-client python-ovos-utils python-ovos-config python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-configuration-provider/*.pkg.tar.xz

python-ovos-phal-plugin-connectivity-events: python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-connectivity-events/*.pkg.tar.xz

python-ovos-phal-plugin-dashboard: python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-dashboard/*.pkg.tar.xz

python-ovos-phal-plugin-display-manager-ipc:  PKGBUILDs/python-ovos-phal-plugin-display-manager-ipc/*.pkg.tar.xz

python-ovos-phal-plugin-gpsd:  PKGBUILDs/python-ovos-phal-plugin-gpsd/*.pkg.tar.xz

python-ovos-phal-plugin-gui-network-client: python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-gui-network-client/*.pkg.tar.xz

python-ovos-phal-plugin-homeassistant: python-nested-lookup python-ovos-bus-client python-ovos-config python-ovos-phal-plugin-oauth python-ovos-plugin-manager python-ovos-utils python-pytube python-youtube-search PKGBUILDs/python-ovos-phal-plugin-homeassistant/*.pkg.tar.xz

python-ovos-phal-plugin-ipgeo: python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-ipgeo/*.pkg.tar.xz

python-ovos-phal-plugin-mk1:  PKGBUILDs/python-ovos-phal-plugin-mk1/*.pkg.tar.xz

python-ovos-phal-plugin-mk2: python-ovos-plugin-manager python-rpi.gpio python-smbus2 PKGBUILDs/python-ovos-phal-plugin-mk2/*.pkg.tar.xz

python-ovos-phal-plugin-network-manager: python-ovos-bus-client python-ovos-plugin-manager python-ovos-utils PKGBUILDs/python-ovos-phal-plugin-network-manager/*.pkg.tar.xz

python-ovos-phal-plugin-notification-widgets: python-mycroft-messagebus-client python-ovos-utils python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-notification-widgets/*.pkg.tar.xz

python-ovos-phal-plugin-oauth: python-ovos-backend-client python-ovos-utils PKGBUILDs/python-ovos-phal-plugin-oauth/*.pkg.tar.xz

python-ovos-phal-plugin-respeaker-2mic:  PKGBUILDs/python-ovos-phal-plugin-respeaker-2mic/*.pkg.tar.xz

python-ovos-phal-plugin-respeaker-4mic:  PKGBUILDs/python-ovos-phal-plugin-respeaker-4mic/*.pkg.tar.xz

python-ovos-phal-plugin-system: python-ovos-bus-client python-ovos-config python-ovos-plugin-manager python-ovos-utils PKGBUILDs/python-ovos-phal-plugin-system/*.pkg.tar.xz

python-ovos-phal-plugin-wallpaper-manager: python-mycroft-messagebus-client python-ovos-plugin-manager python-ovos-utils python-wallpaper-finder PKGBUILDs/python-ovos-phal-plugin-wallpaper-manager/*.pkg.tar.xz

python-ovos-phal-plugin-wifi-setup: python-mycroft-messagebus-client python-ovos-utils python-ovos-plugin-manager PKGBUILDs/python-ovos-phal-plugin-wifi-setup/*.pkg.tar.xz

python-ovos-plugin-manager: python-combo-lock python-langcodes python-ovos-bus-client python-ovos-config python-ovos-utils python-quebra-frases PKGBUILDs/python-ovos-plugin-manager/*.pkg.tar.xz

python-ovos-skill-installer:  PKGBUILDs/python-ovos-skill-installer/*.pkg.tar.xz

python-ovos-skill-manager: python-bs4 python-combo-lock python-json-database python-ovos-config python-ovos-skill-installer python-ovos-utils python-pako python-requests-cache PKGBUILDs/python-ovos-skill-manager/*.pkg.tar.xz

python-ovos-stt-http-server: python-ovos-plugin-manager python-ovos-utils python-uvicorn PKGBUILDs/python-ovos-stt-http-server/*.pkg.tar.xz

python-ovos-stt-plugin-chromium: python-ovos-utils python-ovos-plugin-manager PKGBUILDs/python-ovos-stt-plugin-chromium/*.pkg.tar.xz

python-ovos-stt-plugin-pocketsphinx: python-ovos-plugin-manager python-pocketsphinx python-speechrecognition PKGBUILDs/python-ovos-stt-plugin-pocketsphinx/*.pkg.tar.xz

python-ovos-stt-plugin-selene: python-ovos-utils python-ovos-backend-client python-ovos-plugin-manager PKGBUILDs/python-ovos-stt-plugin-selene/*.pkg.tar.xz

python-ovos-stt-plugin-server: python-ovos-plugin-manager PKGBUILDs/python-ovos-stt-plugin-server/*.pkg.tar.xz

python-ovos-stt-plugin-vosk: python-ovos-skill-installer python-ovos-plugin-manager python-speechrecognition python-vosk PKGBUILDs/python-ovos-stt-plugin-vosk/*.pkg.tar.xz

python-ovos-stt-plugin-whispercpp: python-ovos-plugin-manager python-speechrecognition python-whispercpp PKGBUILDs/python-ovos-stt-plugin-whispercpp/*.pkg.tar.xz

python-ovos-tts-plugin-marytts:  PKGBUILDs/python-ovos-tts-plugin-marytts/*.pkg.tar.xz

python-ovos-tts-plugin-mimic: mycroft-mimic1 python-ovos-plugin-manager PKGBUILDs/python-ovos-tts-plugin-mimic/*.pkg.tar.xz

python-ovos-tts-plugin-mimic2: python-ovos-plugin-manager python-ovos-utils PKGBUILDs/python-ovos-tts-plugin-mimic2/*.pkg.tar.xz

python-ovos-tts-plugin-mimic3: python-ovos-plugin-manager python-ovos-utils python-mycroft-mimic3-tts PKGBUILDs/python-ovos-tts-plugin-mimic3/*.pkg.tar.xz

python-ovos-tts-plugin-mimic3-server: python-ovos-plugin-manager python-ovos-utils PKGBUILDs/python-ovos-tts-plugin-mimic3-server/*.pkg.tar.xz

python-ovos-tts-plugin-pico: python-ovos-plugin-manager PKGBUILDs/python-ovos-tts-plugin-pico/*.pkg.tar.xz

python-ovos-tts-server: python-ovos-plugin-manager python-ovos-utils python-uvicorn PKGBUILDs/python-ovos-tts-server/*.pkg.tar.xz

python-ovos-tts-server-plugin: python-ovos-plugin-manager PKGBUILDs/python-ovos-tts-server-plugin/*.pkg.tar.xz

python-ovos-utils: python-json-database python-kthread PKGBUILDs/python-ovos-utils/*.pkg.tar.xz

python-ovos-vad-plugin-webrtcvad: python-ovos-plugin-manager PKGBUILDs/python-ovos-vad-plugin-webrtcvad/*.pkg.tar.xz

python-ovos-vlc-plugin: python-ovos-plugin-manager python-vlc PKGBUILDs/python-ovos-vlc-plugin/*.pkg.tar.xz

python-ovos-workshop: python-ovos-backend-client python-ovos-bus-client python-ovos-config python-ovos-lingua-franca python-ovos-utils PKGBUILDs/python-ovos-workshop/*.pkg.tar.xz

python-ovos-ww-plugin-pocketsphinx: python-ovos-plugin-manager python-phoneme-guesser python-pocketsphinx python-speechrecognition PKGBUILDs/python-ovos-ww-plugin-pocketsphinx/*.pkg.tar.xz

python-ovos-ww-plugin-precise: python-ovos-plugin-manager python-ovos-utils python-petact python-precise-runner PKGBUILDs/python-ovos-ww-plugin-precise/*.pkg.tar.xz

python-ovos-ww-plugin-precise-lite: ovos-precise-lite-models python-ovos-plugin-manager python-ovos-utils python-precise-lite-runner PKGBUILDs/python-ovos-ww-plugin-precise-lite/*.pkg.tar.xz

python-ovos-ww-plugin-vosk: python-ovos-plugin-manager python-ovos-skill-installer python-vosk PKGBUILDs/python-ovos-ww-plugin-vosk/*.pkg.tar.xz

python-padacioso: python-simplematch PKGBUILDs/python-padacioso/*.pkg.tar.xz

python-pako:  PKGBUILDs-extra/python-pako/*.pkg.tar.xz

python-panphon: aur-repo python-unicodecsv AUR/python-panphon/*.pkg.tar.xz

python-petact:  PKGBUILDs-extra/python-petact/*.pkg.tar.xz

python-phoneme-guesser:  PKGBUILDs-extra/python-phoneme-guesser/*.pkg.tar.xz

python-phonemes2ids: aur-repo AUR/python-phonemes2ids/*.pkg.tar.xz

python-pocketsphinx:  PKGBUILDs-extra/python-pocketsphinx/*.pkg.tar.xz

python-pprintpp:  PKGBUILDs-extra/python-pprintpp/*.pkg.tar.xz

python-precise-lite-runner: python-sonopy python-tflite-runtime PKGBUILDs/python-precise-lite-runner/*.pkg.tar.xz

python-precise-runner:  PKGBUILDs-extra/python-precise-runner/*.pkg.tar.xz

python-py-bandcamp: python-requests-cache PKGBUILDs-extra/python-py-bandcamp/*.pkg.tar.xz

python-pyalsaaudio:  PKGBUILDs-extra/python-pyalsaaudio/*.pkg.tar.xz

python-pydub:  PKGBUILDs-extra/python-pydub/*.pkg.tar.xz

python-pytube:  PKGBUILDs-extra/python-pytube/*.pkg.tar.xz

python-pywebio:  PKGBUILDs-extra/python-pywebio/*.pkg.tar.xz

python-quebra-frases:  PKGBUILDs-extra/python-quebra-frases/*.pkg.tar.xz

python-requests-cache: python-url-normalize PKGBUILDs-extra/python-requests-cache/*.pkg.tar.xz

python-rich-click:  PKGBUILDs-extra/python-rich-click/*.pkg.tar.xz

python-rpi.gpio:  PKGBUILDs-extra/python-rpi.gpio/*.pkg.tar.xz

python-sdnotify:  PKGBUILDs-extra/python-sdnotify/*.pkg.tar.xz

python-simplematch:  PKGBUILDs-extra/python-simplematch/*.pkg.tar.xz

python-smbus2:  PKGBUILDs-extra/python-smbus2/*.pkg.tar.xz

python-sonopy:  PKGBUILDs-extra/python-sonopy/*.pkg.tar.xz

python-speechrecognition:  PKGBUILDs-extra/python-speechrecognition/*.pkg.tar.xz

python-spidev: python-rpi.gpio PKGBUILDs-extra/python-spidev/*.pkg.tar.xz

python-sqlalchemy-json:  PKGBUILDs-extra/python-sqlalchemy-json/*.pkg.tar.xz

python-srt:  PKGBUILDs-extra/python-srt/*.pkg.tar.xz

python-tflite-runtime:  PKGBUILDs-extra/python-tflite-runtime/*.pkg.tar.xz

python-timezonefinder: python-h3 PKGBUILDs-extra/python-timezonefinder/*.pkg.tar.xz

python-tutubo: python-bs4 python-pytube PKGBUILDs-extra/python-tutubo/*.pkg.tar.xz

python-tzlocal:  PKGBUILDs-extra/python-tzlocal/*.pkg.tar.xz

python-unicodecsv: aur-repo AUR/python-unicodecsv/*.pkg.tar.xz

python-url-normalize:  PKGBUILDs-extra/python-url-normalize/*.pkg.tar.xz

python-uvicorn:  PKGBUILDs-extra/python-uvicorn/*.pkg.tar.xz

python-vlc:  PKGBUILDs-extra/python-vlc/*.pkg.tar.xz

python-vosk: python-srt PKGBUILDs-extra/python-vosk/*.pkg.tar.xz

python-wallpaper-finder: python-bs4 python-requests-cache PKGBUILDs-extra/python-wallpaper-finder/*.pkg.tar.xz

python-whispercpp: whisper.cpp python-pydub PKGBUILDs-extra/python-whispercpp/*.pkg.tar.xz

python-xdgenvpy: aur-repo AUR/python-xdgenvpy/*.pkg.tar.xz

python-youtube-search:  PKGBUILDs-extra/python-youtube-search/*.pkg.tar.xz

python-yt-dlp:  PKGBUILDs-extra/python-yt-dlp/*.pkg.tar.xz

whisper.cpp:  PKGBUILDs-extra/whisper.cpp/*.pkg.tar.xz

mycroft-gui-qt6-git: # Ignored

onnxruntime-bin: # Ignored
