#!/bin/sh
case "`cat /proc/device-tree/model`" in
    "Wiren Board rev. 3.2 (i.MX23)" )
    WB_VERSION=32;

    WB_GPIO_MUX_A=34;
    WB_GPIO_MUX_B=33;
    WB_GPIO_MUX_C=32;

    WB_GPIO_PWR_33=39;
    WB_GPIO_RFM_CS=51;
    WB_GPIO_NRF_CS=35;
    WB_GPIO_NRF_EN=37;

    WB_GSM_POWER_TYPE=2
    WB_GPIO_GSM_POWER=245;
    WB_GPIO_GSM_PWRKEY=248;
    WB_GPIO_GSM_STATUS=249;
    WB_GPIO_RELAY_1=247;
    WB_GPIO_RELAY_2=246;

    WB_GPIO_FET_1=52;
    WB_GPIO_FET_2=50;
    WB_GPIO_FET_3=57;
    WB_GPIO_FET_4=54;
    WB_FET_COUNT=4;

    if [ -n "$BASH_VERSION" ]; then
        # eval is for /bin/sh compatibility
        eval "WB_MUX_NAMES_0=( A1 a1 ADC1 adc1)"
        eval "WB_MUX_NAMES_1=( A2 a2 ADC2 adc2)"
        eval "WB_MUX_NAMES_2=( A3 a3 ADC3 adc3)"
        eval "WB_MUX_NAMES_3=( A4 a4 ADC4 adc4)"
        eval "WB_MUX_NAMES_4=( R1 r1)"
        eval "WB_MUX_NAMES_5=( R4 r4)"
        eval "WB_MUX_NAMES_6=( R2 r2)"
        eval "WB_MUX_NAMES_7=( R3 r3)"
    else
        WB_MUX_NAMES_0="A1 a1 ADC1 adc1"
        WB_MUX_NAMES_1="A2 a2 ADC2 adc2"
        WB_MUX_NAMES_2="A3 a3 ADC3 adc3"
        WB_MUX_NAMES_3="A4 a4 ADC4 adc4"
        WB_MUX_NAMES_4="R1 r1"
        WB_MUX_NAMES_5="R4 r4"
        WB_MUX_NAMES_6="R2 r2"
        WB_MUX_NAMES_7="R3 r3"
    fi

    WB_GPIO_A1=${WB_GPIO_FET_1};
    WB_GPIO_A2=${WB_GPIO_FET_2};
    WB_GPIO_A3=${WB_GPIO_FET_3};
    WB_GPIO_A4=${WB_GPIO_FET_4};

    WB_GPIO_W1=4
    WB_GPIO_W2=2
    WB_GPIO_W3=1

    export WB_VERSION WB_GPIO_MUX_A WB_GPIO_MUX_B WB_GPIO_MUX_C \
        WB_GPIO_PWR_33 WB_GPIO_RFM_CS WB_GPIO_NRF_CS WB_GPIO_NRF_EN \
        WB_GSM_POWER_TYPE WB_GPIO_GSM_POWER WB_GPIO_GSM_PWRKEY \
        WB_GPIO_GSM_STATUS WB_GPIO_RELAY_1 WB_GPIO_RELAY_2 \
        WB_GPIO_FET_1 WB_GPIO_FET_2 WB_GPIO_FET_3 WB_GPIO_FET_4 WB_FET_COUNT \
        WB_MUX_NAMES_0 WB_MUX_NAMES_1 WB_MUX_NAMES_2 WB_MUX_NAMES_3 \
        WB_MUX_NAMES_4 WB_MUX_NAMES_5 WB_MUX_NAMES_6 WB_MUX_NAMES_7 \
        WB_GPIO_A1 WB_GPIO_A2 WB_GPIO_A3 WB_GPIO_A4 \
        WB_GPIO_W1 WB_GPIO_W1 WB_GPIO_W1

    ;;
    "Wiren Board rev. 2.8 (i.MX23)" )
    WB_VERSION=28;
    WB_GSM_POWER_TYPE=1

    WB_GPIO_GSM_RESET=7;
    WB_GPIO_GSM_PWRKEY=6;

    WB_GPIO_MUX_A=36;
    WB_GPIO_MUX_B=37;
    WB_GPIO_MUX_C=38;

    WB_GPIO_PWR_33=16;

    WB_GPIO_TB2=32;
    WB_GPIO_TB3=33;
    WB_GPIO_TB4=34;
    WB_GPIO_TB5=35;
    WB_GPIO_TB6=39;
    WB_GPIO_TB7=1;
    WB_GPIO_TB19=60;

    WB_GPIO_FET_1=${WB_GPIO_TB2};
    WB_GPIO_FET_2=${WB_GPIO_TB3};
    WB_GPIO_FET_3=${WB_GPIO_TB4};
    WB_GPIO_FET_4=${WB_GPIO_TB5};
    WB_GPIO_FET_5=${WB_GPIO_TB6};
    WB_GPIO_FET_6=${WB_GPIO_TB7};
    WB_GPIO_FET_7=${WB_GPIO_TB19};
    WB_FET_COUNT=7;


    if [ -n "$BASH_VERSION" ]; then
        # eval is for /bin/sh compatibility
        eval "WB_MUX_NAMES_0=( tb3 )"
        eval "WB_MUX_NAMES_1=( tb4 )"
        eval "WB_MUX_NAMES_2=( tb5 )"
        eval "WB_MUX_NAMES_3=( tb2 )"
        eval "WB_MUX_NAMES_4=( tb6 )"
        eval "WB_MUX_NAMES_5=( vin )"
        eval "WB_MUX_NAMES_6=( tb7 )"
        eval "WB_MUX_NAMES_7=( tb9 )"
    else
        WB_MUX_NAMES_0="tb3"
        WB_MUX_NAMES_1="tb4"
        WB_MUX_NAMES_2="tb5"
        WB_MUX_NAMES_3="tb2"
        WB_MUX_NAMES_4="tb6"
        WB_MUX_NAMES_5="vin"
        WB_MUX_NAMES_6="tb7"
        WB_MUX_NAMES_7="tb9"
    fi


    export WB_VERSION WB_GSM_POWER_TYPE WB_GPIO_GSM_RESET \
        WB_GPIO_GSM_PWRKEY WB_GPIO_MUX_A WB_GPIO_MUX_B WB_GPIO_MUX_C \
        WB_GPIO_PWR_33 WB_GPIO_TB2 WB_GPIO_TB3 WB_GPIO_TB4 \
        WB_GPIO_TB5 WB_GPIO_TB6 WB_GPIO_TB7 WB_GPIO_TB19 \
        WB_GPIO_FET_1 WB_GPIO_FET_2 WB_GPIO_FET_3 WB_GPIO_FET_4 \
        WB_GPIO_FET_5 WB_GPIO_FET_6 WB_GPIO_FET_7 WB_FET_COUNT \
        WB_MUX_NAMES_0 WB_MUX_NAMES_1 WB_MUX_NAMES_2 \
        WB_MUX_NAMES_3 WB_MUX_NAMES_4 WB_MUX_NAMES_5 \
        WB_MUX_NAMES_6 WB_MUX_NAMES_7

    ;;
    * )
    WB_VERSION="unknown";
    ;;
esac

#~ echo "Wiren Board Version is: $WB_VERSION" 1>&2

