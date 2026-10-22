## ****************************************************************************
## ****************************************************************************
## Copyright SoC Design Research Group, All rights reserved.
## Electronics and Telecommunications Research Institute (ETRI)
##
## THESE DOCUMENTS CONTAIN CONFIDENTIAL INFORMATION AND KNOWLEDGE 
## WHICH IS THE PROPERTY OF ETRI. NO PART OF THIS PUBLICATION IS 
## TO BE USED FOR ANY OTHER PURPOSE, AND THESE ARE NOT TO BE 
## REPRODUCED, COPIED, DISCLOSED, TRANSMITTED, STORED IN A RETRIEVAL 
## SYSTEM OR TRANSLATED INTO ANY OTHER HUMAN OR COMPUTER LANGUAGE, 
## IN ANY FORM, BY ANY MEANS, IN WHOLE OR IN PART, WITHOUT THE 
## COMPLETE PRIOR WRITTEN PERMISSION OF ETRI.
## ****************************************************************************
## 2022-11-14
## Kyuseung Han (han@etri.re.kr)
## ****************************************************************************
## ****************************************************************************

ifdef RVX_MINI_HOME
	include ${RVX_MINI_HOME}/rvx_config.mh
else
	include ${RVX_DEVKIT_HOME}/rvx_config.mh
endif

TEMPLATE_FILE = ${RVX_ENV}/util/Makefile.fakefile.template
include ${RVX_UTIL_HOME}/template_makefile.mh

ifndef FILE_LIST
FILE_LIST=${CURDIR}/target/*
endif

ifndef ROM_NAME
ROM_NAME=NONE
endif

PLATFORM_DIR = $(call absolute_path,${CURDIR}/../..)

GERENATRED_DIRNAME=generated
GERENATRED_SSW_DIRNAME=ssw
UTIL_DIR = ${PLATFORM_DIR}/util

TARGET_DIR?=${CURDIR}/target
RESULT_DIR?=${UTIL_DIR}/${GERENATRED_DIRNAME}/${GERENATRED_SSW_DIRNAME}
RESULT_DIR_ABS=$(call absolute_path,${RESULT_DIR})

clean:
	@true

convert: _convert update_api

_convert:
	${PYTHON3_CMD} ${RVX_ENV}/util/convert_file.py -i ${FILE_LIST} -o ${RESULT_DIR} -r ${ROM_NAME}

generated_clean:
	@cd ${RESULT_DIR} && rm -rf *_file.*

generated_mkdir:
	@cd ${UTIL_DIR} && mkdir -p ${GERENATRED_DIRNAME}

generated_ssw_mkdir: generated_mkdir
	@mkdir -p ${RESULT_DIR_ABS}
	@cp -f ${RVX_ENV}/util/gitignore.generated.txt ${RESULT_DIR}/.gitignore

add:
	mkdir -p target
	cp -r ${ADD_FILE_LIST} ${TARGET_DIR}

remove:
	-cd ${TARGET_DIR} && rm -rf ${REMOVE_FILE_LIST}

all: generated_ssw_mkdir generated_clean convert

USER_DIR = ${PLATFORM_DIR}/user
API_DIR = ${USER_DIR}/api

FAKEFILE_API_LIST=$(wildcard ${API_DIR}/*_*_file.*)
FAKEFILE_API_NAME_LIST=$(notdir ${FAKEFILE_API_LIST})

update_api: $(addsuffix .update_api, ${FAKEFILE_API_NAME_LIST})

$(addsuffix .update_api, ${FAKEFILE_API_NAME_LIST}):%.update_api:
	@if [ -f ${RESULT_DIR}/$(*) ]; \
	then \
		mv -f ${RESULT_DIR}/$(*) ${API_DIR}; \
	fi

FORCE:

.PHONY: FORCE clean
