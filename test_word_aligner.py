import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from cocotb.triggers import Timer
from cocotb.handle import *
from bitarray import bitarray

def tobin(number, nbit):
    b = bin(number)[2:]
    return '0' * (nbit - len(b)) + b

def listtobitarray(lst, nbit):
    outbit = bitarray(len(lst) * nbit)
    for x in range(len(lst)):
        outbit[x*nbit:(x+1)*nbit] = bitarray(tobin(lst[x], nbit))
    return outbit


SAV8 =  [0xFF,0x00,0x00,0x80]
EAV8 =  [0xFF,0x00,0x00,0x9D]
# SAV8_b = bytes.fromhex(SAV8)
# EAV8_b = bytes.fromhex(EAV8)
BIT8GEN = [i for i in  range(10,30)]
BIT8 = listtobitarray([*SAV8, *BIT8GEN, *EAV8], 8)

# print(tobin(0x074, 10))

SAV10 = [ 0x3FF, 0x00, 0x00, 0x200]
EAV10 = [ 0x3FF, 0x00, 0x00, 0x274]
BIT10GEN = [i for i in  range(10,30)]
BIT10 = listtobitarray([*SAV10, *BIT10GEN, *EAV10], 10)

SAV12 = [ 0xFFF, 0x00, 0x00, 0x800]
EAV12 = [ 0xFFF, 0x00, 0x00, 0x9D0]
BIT12GEN = [i for i in  range(10,15)]
BIT12 = listtobitarray([*SAV12, *BIT12GEN, *EAV12], 12)


z1b = bitarray(1)
# SAV9 =  'FF000080'
# SAV8 =  'FF000080'

@cocotb.test()
async def test_dff_simple(dut):
    """ Test that d propagates to q """

    clock = Clock(dut.clk_i, 10, units="ns")  # Create a 10us period clock on port clk
    cocotb.fork(clock.start())  # Start the clock

    # for i in range(len(SAV8_b)):
    #     await FallingEdge(dut.clk_i)
    #     dut.word_i.value = SAV8_b[i]
    # for i in range(15):
    #     await FallingEdge(dut.clk_i)
    #     dut.word_i.value = i + 18
    #     await RisingEdge(dut.clk_i)
    # for i in range(len(EAV8_b)):
    #     await FallingEdge(dut.clk_i)
    #     dut.word_i.value = EAV8_b[i]
    if False:
        BIT8_b = BIT8.tobytes()
        for i in range(len(BIT8_b)):
            await FallingEdge(dut.clk_i)
            dut.word_i.value = BIT8_b[i]
            await RisingEdge(dut.clk_i)
            try:
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            except:
                pass
        # await Timer(200, units='ns')    
        for clk in range(5):
            await RisingEdge(dut.clk_i)
            try:
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            except:
                pass
        print("Done")
        for x in range(10):
            print("Shift {} bits".format(x+1))
            BIT8.insert(0,0)                
            BIT8_b = BIT8.tobytes()
            for i in range(len(BIT8_b)):
                await FallingEdge(dut.clk_i)
                dut.word_i.value = BIT8_b[i]
                await RisingEdge(dut.clk_i)
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            # await Timer(200, units='ns')
            for clk in range(5):
                await RisingEdge(dut.clk_i)
                try:
                    if dut.word_valid_o.value == 1:
                        print(dut.word_o.value, dut.word_r.value)    
                except:
                    pass



    # await Timer(1, units='us')
    if False:
        print('########### Test 10 bits ##############')
        BIT10_b = BIT10.tobytes()
        for i in range(len(BIT10_b)):
            await FallingEdge(dut.clk_i)
            dut.word_i.value = BIT10_b[i]
            await RisingEdge(dut.clk_i)
            try:
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            except:
                pass 

        for clk in range(5):
            await RisingEdge(dut.clk_i)
            try:
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            except:
                pass
        # z1b.append(BIT10)
        for x in range(10):
            print("Shift {} bits".format(x+1))
            BIT10.insert(0,0)    
            BIT10_b = BIT10.tobytes()
            for i in range(len(BIT10_b)):
                await FallingEdge(dut.clk_i)
                dut.word_i.value = BIT10_b[i]
                await RisingEdge(dut.clk_i)
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            # await Timer(100, units='ns')
            for clk in range(5):
                await RisingEdge(dut.clk_i)
                try:
                    if dut.word_valid_o.value == 1:
                        print(dut.word_o.value, dut.word_r.value)    
                except:
                    pass
    if True:
        print('########### Test 12 bits ##############')
        BIT12_b = BIT12.tobytes()
        for i in range(len(BIT12_b)):
            await FallingEdge(dut.clk_i)
            dut.word_i.value = BIT12_b[i]
            await RisingEdge(dut.clk_i)
            try:
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            except:
                pass 

        for clk in range(5):
            await RisingEdge(dut.clk_i)
            try:
                if dut.word_valid_o.value == 1:
                    print(dut.word_o.value, dut.word_r.value)    
            except:
                pass
        # z1b.append(BIT12)
        for x in range(10):
            print("Shift {} bits".format(x+1))
            BIT12.insert(0,0)    
            BIT12_b = BIT12.tobytes()
            for i in range(len(BIT12_b)):
                await FallingEdge(dut.clk_i)
                dut.word_i.value = BIT12_b[i]
                await RisingEdge(dut.clk_i)
                try:
                    if dut.word_valid_o.value == 1:
                        print(dut.word_o.value, dut.word_r.value)    
                except:
                    pass  
            # await Timer(100, units='ns')
            for clk in range(5):
                await RisingEdge(dut.clk_i)
                try:
                    if dut.word_valid_o.value == 1:
                        print(dut.word_o.value, dut.word_r.value)    
                except:
                    pass

    # for i in range(len(BIT10GEN_b)):
    #     await FallingEdge(dut.clk_i)
    #     dut.word_i.value = BIT10GEN_b[i]
    # for i in range(len(EAV10_b)):
    #     await FallingEdge(dut.clk_i)
    #     dut.word_i.value = EAV10_b[i]

    await Timer(1, units='us')
    # await FallingEdge(dut.clk_i)
    # dut.word_i.value = 0x15
    # await FallingEdge(dut.clk_i)
    # dut.word_i.value = 0x16
    # await FallingEdge(dut.clk_i)
    # dut.word_i.value = 0x17
    # await FallingEdge(dut.clk_i)
    # dut.word_i.value = 0x18

    await Timer(1, units='us')
    #dut.CNTRL <= 1
    assert True
    # exit(1)
#    for i in range(10000000):
#        val = random.randint(0, 1)
#        dut.d <= val  # Assign the random value val to the input port d
#        await FallingEdge(dut.CLK)
#        assert dut.q == val, "output q was incorrect on the {}th cycle".format(i)
    if False:
        await Timer(1, units='ms')
        dut.CNTRL <= 1
        await FallingEdge(dut.CLK)
        dut.CNTRL <= Release()
        #await Timer(10, units='us')
        print("########### Here0")
        await Timer(200, units='us')
        print("########### Here1")
        await FallingEdge(dut.CLK)
        dut.XTRIGStart <= 1
        await FallingEdge(dut.CLK)
        dut.XTRIGStart <= 0
        await Timer(10, units='ms')
        #await FallingEdge(dut.XVSo)
        #await Timer(4, units='ms')
        dut.XTRIGStart <= 1
        await Timer(4, units='ms')
        #await FallingEdge(dut.CLK)     
        if False:
            print("########### Here")
            #dut.CNTRL[0] <= 1
            
            #await FallingEdge(dut.clk12)
            dut.XTRIGStart <= Release()
            #  <= Release()
            await Timer(1, units='ms')


