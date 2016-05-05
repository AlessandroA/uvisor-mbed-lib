###########################################################################
#
#  Copyright (c) 2013-2016, ARM Limited, All Rights Reserved
#  SPDX-License-Identifier: Apache-2.0
#
#  Licensed under the Apache License, Version 2.0 (the "License"); you may
#  not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################

# Toolchain
PREFIX:=arm-none-eabi-
GDB:=$(PREFIX)gdb
OBJDUMP:=$(PREFIX)objdump
NEO_PY=deploy/neo/neo.py

# Translate between uVisor namespace and mbed namespace
TARGET_TRANSLATION:=MCU_K64F.kinetis EFM32.efm32 STM32F4.stm32
TARGET_DST:=targets
TARGET_SRC:=source
TARGET_INC:=include

# uVisor source directory - hidden from mbed via TARGET_IGNORE
UVISOR_DIR=deploy/TARGET_IGNORE/uvisor
UVISOR_API:=$(UVISOR_DIR)/api
UVISOR_GIT_CFG=$(UVISOR_DIR)/.git/config

# Derive variables from user configuration
TARGET_LIST:=$(subst .,,$(suffix $(TARGET_TRANSLATION)))
TARGET_LIST_DIR_SRC:=$(addprefix $(UVISOR_API)/lib/,$(TARGET_LIST))
TARGET_LIST_DIR_DST:=$(addprefix $(TARGET_DST)/,$(TARGET_LIST))
TARGET_LIST_RELEASE:=$(addsuffix /release,$(TARGET_LIST_DIR_DST))
TARGET_LIST_DEBUG:=$(addsuffix /debug,$(TARGET_LIST_DIR_DST))

.PHONY: all deploy rsync publish uvisor uvisor-compile clean

all: uvisor

deploy: clean uvisor

rsync:
	#
	# Copying uVisor into mbed library...
	rm -rf $(TARGET_DST)
	rsync -a --exclude='*.txt' $(TARGET_LIST_DIR_SRC) $(TARGET_DST)
	#
	# Copying uVisor headers to mbed includes...
	rm -rf $(TARGET_INC)/uvisor
	mkdir -p $(TARGET_INC)/uvisor/api/inc
	rsync -a --delete $(UVISOR_API)/inc/ $(TARGET_INC)/uvisor/api/inc
	#
	# Copying uVisor source file to mbed source...
	cp $(UVISOR_API)/src/unsupported.c $(TARGET_SRC)/

TARGET_M%: $(TARGET_DST)/*/*/*_m%_*.a
	@printf "#\n# Copying $@ files...\n"
	mkdir $(foreach file,$^,$(dir $(file))$@)
	$(foreach file,$^,mv $(file) $(dir $(file))$@/lib$(notdir $(file));)

publish: rsync TARGET_M3 TARGET_M4
	#
	# Rename release directorires to TARGET_RELEASE filters...
	$(foreach dir, $(TARGET_LIST_RELEASE),mv $(dir) $(dir $(dir))TARGET_RELEASE;)
	#
	# Rename debug directorires to TARGET_DEBUG filters...
	$(foreach dir, $(TARGET_LIST_DEBUG),mv $(dir) $(dir $(dir))TARGET_DEBUG;)
	#
	# Rename target directorires to TARGET_* filters...
	$(foreach target, $(TARGET_TRANSLATION),mv targets/$(subst .,,$(suffix $(target))) targets/TARGET_$(basename $(target));)

uvisor: uvisor-compile publish

uvisor-compile:
	make -C $(UVISOR_DIR)

clean:
	make -C $(UVISOR_DIR) clean
