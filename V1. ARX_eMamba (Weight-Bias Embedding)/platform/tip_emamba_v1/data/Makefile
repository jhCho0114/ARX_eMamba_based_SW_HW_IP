# data/ 디렉터리용 Makefile
# 사용법:
#   make gen ev01
#   make gen app/ev01
#   make auto ev01
#   make clean ev01
#   make regen ev01

PYTHON ?= python3
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PLATFORM_DIR := $(abspath $(MAKEFILE_DIR)/..)
APP_ROOT_DIR := $(abspath $(PLATFORM_DIR)/app)

CONVERTER := $(MAKEFILE_DIR)txt_to_header.py
JSON2TXT := $(MAKEFILE_DIR)json_to_txt.py
INPUT_DIR := $(abspath $(MAKEFILE_DIR))

# gen / auto / clean / regen 뒤에 오는 앱 이름
GOAL_APPS := $(filter-out gen regen clean auto help json2txt,$(MAKECMDGOALS))
ifndef APP
APP := $(firstword $(GOAL_APPS))
endif

ifneq ($(filter gen regen clean auto,$(MAKECMDGOALS)),)
ifeq ($(strip $(APP)),)
$(error app name is required. ex: make gen my_test_app or make gen app/my_test_app)
endif
endif

ifeq ($(findstring /,$(APP)),)
APP_DIR := $(APP_ROOT_DIR)/$(APP)
else
APP_DIR := $(abspath $(PLATFORM_DIR)/$(APP))
endif
OUTPUT_DIR := $(APP_DIR)/include

ifneq ($(filter gen regen clean auto,$(MAKECMDGOALS)),)
ifeq ($(strip $(APP)),)
$(error app name is required. ex: make gen ev01 or make gen app/ev01)
endif
ifeq ($(wildcard $(APP_DIR)),)
$(error app directory not found: $(APP_DIR))
endif
endif

.PHONY: gen regen clean auto help json2txt

json2txt:
	@set -e; \
	found=0; \
	for json in "$(INPUT_DIR)"/*.json; do \
		[ -e "$$json" ] || continue; \
		found=1; \
		echo "JSON -> TXT: $$json"; \
		"$(PYTHON)" "$(JSON2TXT)" "$$json"; \
	done; \
	if [ "$$found" -eq 0 ]; then \
		echo "JSON 파일 없음, 변환 건너뜀"; \
	fi

gen:
	@echo "TXT -> H: $(INPUT_DIR) -> $(OUTPUT_DIR)"
	@$(PYTHON) "$(CONVERTER)" \
		--input-dir "$(INPUT_DIR)" \
		--output-dir "$(OUTPUT_DIR)"

auto: json2txt gen

clean:
	@rm -rf "$(OUTPUT_DIR)"
	@echo "삭제: $(OUTPUT_DIR)"

regen: clean auto

help:
	@echo "사용법:"
	@echo "  make gen ev01          # data/*.txt -> app/ev01/include/*.h"
	@echo "  make gen app/ev01      # 위와 동일"
	@echo "  make auto ev01         # data/*.json -> *.txt 후 gen"
	@echo "  make clean ev01        # app/ev01/include 삭제"
	@echo "  make regen ev01        # clean 후 auto"
	@echo ""
	@echo "스크립트용: make gen APP=ev01"

# make gen ev01 처럼 앱 이름만 추가 goal로 넘길 때 오류 방지
ifneq ($(APP),)
.PHONY: $(APP)
$(APP):
	@:
endif

app/%:
	@: