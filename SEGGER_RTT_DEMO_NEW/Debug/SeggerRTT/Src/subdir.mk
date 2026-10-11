################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../SeggerRTT/Src/SEGGER_RTT.c \
../SeggerRTT/Src/SEGGER_RTT_printf.c \
../SeggerRTT/Src/rtt_log.c 

OBJS += \
./SeggerRTT/Src/SEGGER_RTT.o \
./SeggerRTT/Src/SEGGER_RTT_printf.o \
./SeggerRTT/Src/rtt_log.o 

C_DEPS += \
./SeggerRTT/Src/SEGGER_RTT.d \
./SeggerRTT/Src/SEGGER_RTT_printf.d \
./SeggerRTT/Src/rtt_log.d 


# Each subdirectory must supply rules for building sources it contributes
SeggerRTT/Src/%.o SeggerRTT/Src/%.su SeggerRTT/Src/%.cyclo: ../SeggerRTT/Src/%.c SeggerRTT/Src/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DDEBUG -DUSE_PWR_LDO_SUPPLY -DUSE_HAL_DRIVER -DSTM32H723xx -c -I../Core/Inc -I../Drivers/STM32H7xx_HAL_Driver/Inc -I../Drivers/STM32H7xx_HAL_Driver/Inc/Legacy -I../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../Drivers/CMSIS/Include -I"C:/STM32_NEW_WORKSPACE/SEGGER_RTT_DEMO_NEW/SeggerRTT/Inc" -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-SeggerRTT-2f-Src

clean-SeggerRTT-2f-Src:
	-$(RM) ./SeggerRTT/Src/SEGGER_RTT.cyclo ./SeggerRTT/Src/SEGGER_RTT.d ./SeggerRTT/Src/SEGGER_RTT.o ./SeggerRTT/Src/SEGGER_RTT.su ./SeggerRTT/Src/SEGGER_RTT_printf.cyclo ./SeggerRTT/Src/SEGGER_RTT_printf.d ./SeggerRTT/Src/SEGGER_RTT_printf.o ./SeggerRTT/Src/SEGGER_RTT_printf.su ./SeggerRTT/Src/rtt_log.cyclo ./SeggerRTT/Src/rtt_log.d ./SeggerRTT/Src/rtt_log.o ./SeggerRTT/Src/rtt_log.su

.PHONY: clean-SeggerRTT-2f-Src

