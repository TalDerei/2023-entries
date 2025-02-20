#
# Copyright 2019-2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#

############################## Help Section ##############################
ifneq ($(findstring Makefile, $(MAKEFILE_LIST)), Makefile)
help:
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to generate the design for specified Target and Shell."
	$(ECHO) ""
	$(ECHO) "  make run TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to run application in emulation."
	$(ECHO) ""
	$(ECHO) "  make build TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to build xclbin application."
	$(ECHO) ""
	$(ECHO) "  make host"
	$(ECHO) "      Command to build host application."
	$(ECHO) ""
	$(ECHO) "  make clean "
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""

endif

############################## Setting up Project Variables ##############################
TARGET := hw
ZPRIZE_MUL_MOD := true_mul_mod
VPP_LDFLAGS :=
include ./utils.mk

TEMP_DIR := ./_x.$(TARGET).$(XSA)
BUILD_DIR := ./build_dir.$(TARGET).$(XSA)

LINK_OUTPUT := $(BUILD_DIR)/${TOP_LEVEL_NAME}.link.xclbin
PACKAGE_OUT = ./package.$(TARGET)

VPP_PFLAGS := 
CMD_ARGS = $(BUILD_DIR)/${TOP_LEVEL_NAME}.xclbin
include config.mk


########################## Checking if PLATFORM in allowlist #######################
PLATFORM_BLOCKLIST += nodma 
############################## Setting up Host Variables ##############################
#Include Required Host Source Files
# shen

# Host compiler global settings

############################## Setting up Kernel Variables ##############################
# Kernel compiler global settings
VPP_FLAGS += --save-temps 

EXECUTABLE = ./rtl_${TOP_LEVEL_NAME}
EMCONFIG_DIR = $(TEMP_DIR)


############################## Setting Targets ##############################
.PHONY: all clean cleanall docs emconfig
all: check-platform check-device check-vitis  $(BUILD_DIR)/${TOP_LEVEL_NAME}.xclbin emconfig


.PHONY: build
build: check-vitis check-device $(BUILD_DIR)/${TOP_LEVEL_NAME}.xclbin

.PHONY: xclbin
xclbin: build


XO_FILES=$(addsuffix .xo,$(addprefix $(TEMP_DIR)/,$(KERNEL_NAMES)))

print_info1:
	@echo "	XO_FILES: $(XO_FILES)"
	@echo "	KERNEL_NAMES: $(KERNEL_NAMES)"
	@echo "	TOP_LEVEL_NAME: $(TOP_LEVEL_NAME)"

ifeq ($(ZPRIZE_MUL_MOD),$(filter $(ZPRIZE_MUL_MOD),fake))
SIM_MOD = fileset.sim_1.verilog_define=ZPRIZE_FAKE_MUL_MOD
else
SIM_MOD = fileset.sim_1.verilog_define=ZPRIZE_MUL_MOD
endif

# Building kernel
$(BUILD_DIR)/$(TOP_LEVEL_NAME).xclbin: $(XO_FILES)
# # Building kernel
# $(BUILD_DIR)/${TOP_LEVEL_NAME}.xclbin: $(TEMP_DIR)/${TOP_LEVEL_NAME}.xo
	mkdir -p $(BUILD_DIR)
	v++ -l $(VPP_FLAGS) -t $(TARGET) --platform $(PLATFORM) $(VPP_LDFLAGS) --temp_dir $(TEMP_DIR) \
	--config ./link.cfg \
	--kernel_frequency 280 \
	--vivado.prop fileset.sim_1.xsim.elaborate.debug_level=all \
	--vivado.prop fileset.sim_1.xsim.simulate.log_all_signals=true \
	--vivado.prop run.ulp_krnl_msm_rtl_1_0_synth_1.strategy=Flow_PerfOptimized_high \
	--vivado.prop run.ulp_krnl_msm_rtl_1_0_synth_1.steps.synth_design.args.directive=RuntimeOptimized \
	--vivado.prop run.my_rm_synth_1.strategy=Flow_PerfOptimized_high \
	--vivado.prop run.my_rm_synth_1.steps.synth_design.args.directive=RuntimeOptimized \
	--vivado.prop run.impl_1.strategy=Performance_Explore \
	--vivado.prop run.impl_1.steps.phys_opt_design.is_enabled=1 \
	--vivado.prop run.impl_1.STEPS.OPT_DESIGN.TCL.POST=zprize_3core_place.tcl \
	--advanced.param compiler.skipTimingCheckAndFrequencyScaling=TRUE \
	--vivado.prop $(SIM_MOD) \
	\
	-o'$(LINK_OUTPUT)' $(+)
	#

	# --to_step vpl.synth \
	# --reuse_impl *.dcp \
	
	v++ -p $(LINK_OUTPUT) -t $(TARGET) --platform $(PLATFORM) --package.out_dir $(PACKAGE_OUT) -o $(BUILD_DIR)/${TOP_LEVEL_NAME}.xclbin
############################## Setting Rules for Host (Building Host Executable) ##############################
$(EXECUTABLE): $(HOST_SRCS) | check-xrt
		g++ -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

emconfig:$(EMCONFIG_DIR)/emconfig.json
$(EMCONFIG_DIR)/emconfig.json:
	emconfigutil --platform $(PLATFORM) --od $(EMCONFIG_DIR)

############################## Setting Essential Checks and Running Rules ##############################
run: all
# shen
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	cp -rf $(EMCONFIG_DIR)/emconfig.json .
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(EXECUTABLE) $(CMD_ARGS)
endif

.PHONY: test
test: $(EXECUTABLE)
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(EXECUTABLE) $(CMD_ARGS)
endif

############################## Cleaning Rules ##############################
# Cleaning stuff
clean:
	-$(RMDIR) $(EXECUTABLE) $(XCLBIN)/{*sw_emu*,*hw_emu*} 
	-$(RMDIR) profile_* TempConfig system_estimate.xtxt *.rpt *.csv 
	-$(RMDIR) src/*.ll *v++* .Xil emconfig.json dltmp* xmltmp* *.log *.jou *.wcfg *.wdb

cleanall: clean
	-$(RMDIR) build_dir*
	-$(RMDIR) package.*
	-$(RMDIR) _x* *xclbin.run_summary qemu-memory-_* emulation _vimage pl* start_simulation.sh *.xclbin
	-$(RMDIR) ./tmp_kernel_pack* ./packaged_kernel* 
