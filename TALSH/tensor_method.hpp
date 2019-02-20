/** TAL-SH: Tensor Method Interface
REVISION: 2019/02/20

Copyright (C) 2018-2019 Dmitry I. Lyakh (Liakh)
Copyright (C) 2018-2019 Oak Ridge National Laboratory (UT-Battelle) **/

#ifndef TENSOR_METHOD_HPP_
#define TENSOR_METHOD_HPP_

#ifdef EXATN_SERVICE

//Byte packet (interoperable):
typedef struct{
 void * base_addr;              //base address (non-owning pointer to an application owned buffer)
 unsigned long long size_bytes; //actual size of the byte packet in bytes
} BytePacket;


//Dense tensor block (interoperable):
typedef struct{
 int num_dims;      //number of dimensions
 int data_kind;     //data kind
 void * body_ptr;   //non-owning pointer to the tensor data
 long long * bases; //dimension bases
 long long * dims;  //dimension extents
} TensorDenseBlock;


//External tensor method (identifiable):
template <typename IdentifiableConcept>
class TensorMethod: public IdentifiableConcept{
public:

 TensorMethod() = default;
 virtual ~TensorMethod() = default;

 //Packing/unpacking data members into/from a plain byte packet:
 virtual void pack(BytePacket & packet) = 0;
 virtual void unpack(const BytePacket & packet) = 0;

 //Application-defined external tensor method:
 virtual int apply(const TensorDenseBlock & local_tensor) = 0;

};

#endif //EXATN_SERVICE

#endif //TENSOR_METHOD_HPP_
