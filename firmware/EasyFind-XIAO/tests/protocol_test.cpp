#include "remote_protocol.h"
#include <cassert>
#include <cstring>
#include <cstdio>
#include <initializer_list>

int main() {
    remote::Request request{};
    uint8_t read[] = {0x53,0x46,1,1,7,0,0};
    assert(remote::decode(read,sizeof(read),request));
    assert(request.sequence==7 && remote::validate(request,false)==0);
    uint8_t write[] = {0x53,0x46,1,2,0x34,0x12,1,5};
    assert(remote::decode(write,sizeof(write),request));
    assert(request.sequence==0x1234 && request.delay==5);
    assert(remote::validate(request,false)==0);
    assert(remote::validate(request,true)==4);
    uint8_t payload[]={0,5}, reply[20]{};
    uint8_t expected[]={0x53,0x46,1,0x82,0x34,0x12,2,0,5};
    assert(remote::frame(0x82,request.sequence,payload,2,reply)==sizeof(expected));
    assert(!memcmp(reply,expected,sizeof(expected)));
    write[7]=31;
    assert(remote::decode(write,sizeof(write),request));
    assert(remote::validate(request,false)==1);
    for (uint8_t delay : {uint8_t(0),uint8_t(30)}) {
        write[7]=delay;
        assert(remote::decode(write,sizeof(write),request));
        assert(remote::validate(request,false)==0);
    }
    assert(!remote::decode(nullptr,0,request));
    for(size_t length=0;length<sizeof(write);++length)
        assert(!remote::decode(write,length,request));
    write[2]=2; assert(!remote::decode(write,sizeof(write),request)); write[2]=1;
    write[4]=write[5]=0; assert(!remote::decode(write,sizeof(write),request)); write[4]=1;
    write[6]=2; assert(!remote::decode(write,sizeof(write),request)); write[6]=1;
    write[3]=1; assert(remote::decode(write,sizeof(write),request));
    assert(remote::validate(request,false)==1);
    write[3]=99; assert(!remote::decode(write,sizeof(write),request));
    assert(remote::frame(1,1,payload,14,reply)==0);
    assert(remote::remaining(1000,4000)==3);
    assert(remote::remaining(1001,4000)==3);
    assert(remote::remaining(3000,4000)==1);
    assert(remote::remaining(3999,4000)==1);
    assert(remote::remaining(4000,4000)==0);
    assert(remote::remaining(4001,4000)==0);
    assert(remote::remaining(0xfffffff0u,0x00000ba8u)==3);
    assert(remote::remaining(0x00000ba9u,0x00000ba8u)==0);
    assert(remote::kCapabilities == 0x1f);
    uint8_t enable[] = {0x53,0x46,1,4,1,0,0};
    assert(remote::decode(enable,sizeof(enable),request));
    assert(remote::validate(request,true)==0); // Find control is independent of shutter busy state.
    uint8_t ack[] = {0x53,0x46,1,3,2,0,9,0x88,0x77,0x66,0x55,0x44,0x33,0x22,0x11,0};
    assert(remote::decode(ack,sizeof(ack),request));
    assert(request.findID==0x1122334455667788ULL && request.findStatus==0);
    assert(remote::validate(request,true)==0);
    for (uint8_t status = 0; status <= 3; ++status) {
        ack[15]=status;
        assert(remote::decode(ack,sizeof(ack),request));
        assert(remote::validate(request,false)==(status<=2 ? 0 : 1));
    }
    ack[15]=0;
    memset(ack+7,0,8);
    assert(remote::decode(ack,sizeof(ack),request));
    assert(remote::validate(request,false)==1);
    ack[6]=8;
    assert(remote::decode(ack,sizeof(ack)-1,request));
    assert(remote::validate(request,false)==1);
    enable[6]=1;
    uint8_t invalidEnable[]={0x53,0x46,1,4,1,0,1,1};
    assert(remote::decode(invalidEnable,sizeof(invalidEnable),request));
    assert(remote::validate(request,false)==1);
    uint8_t findPayload[11]={5,0};
    remote::write64(0x1122334455667788ULL,findPayload+2);
    findPayload[10]=30;
    uint8_t reliableExpected[]={0x53,0x46,1,0xe0,0,0,11,5,0,0x88,0x77,0x66,0x55,0x44,0x33,0x22,0x11,30};
    assert(remote::frame(0xe0,0,findPayload,11,reply)==sizeof(reliableExpected));
    assert(!memcmp(reply,reliableExpected,sizeof(reliableExpected)));
    puts("PASS: golden frames, delay bounds, find control, malformed requests, busy state and timer wrap");
}
