/** ExaTensor::TAL-SH: Device-unified user-level C++ API header.
REVISION: 2018/03/29

Copyright (C) 2014-2017 Dmitry I. Lyakh (Liakh)
Copyright (C) 2014-2017 Oak Ridge National Laboratory (UT-Battelle)

This file is part of ExaTensor.

ExaTensor is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ExaTensor is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with ExaTensor. If not, see <http://www.gnu.org/licenses/>.
------------------------------------------------------------------------
**/

#ifndef _TALSHXX_HPP
#define _TALSHXX_HPP

#include <complex>
#include <initializer_list>
#include <string>

#include "talsh.h"        //TAL-SH C header
#include "talsh_task.hpp" //TAL-SH C++ task

namespace talsh{

//Constants:

static const std::size_t DEFAULT_HOST_BUFFER_SIZE = TALSH_NO_HOST_BUFFER;

//Tensor data kind (static type VS numeric constant conversions):

template <typename T>
struct TensorData{
 static constexpr int kind = NO_TYPE;
 static constexpr bool supported = false;
};
template <>
struct TensorData<float>{
 static constexpr int kind = R4;
 static constexpr bool supported = true;
 static constexpr float unity = 1.0f;
};
template <>
struct TensorData<double>{
 static constexpr int kind = R8;
 static constexpr bool supported = true;
 static constexpr double unity = 1.0;
};
template <>
struct TensorData<std::complex<float>>{
 static constexpr int kind = C4;
 static constexpr bool supported = true;
 static constexpr std::complex<float> unity = std::complex<float>(1.0f,0.0f);
};
template <>
struct TensorData<std::complex<double>>{
 static constexpr int kind = C8;
 static constexpr bool supported = true;
 static constexpr std::complex<double> unity = std::complex<double>(1.0,0.0);
};

template <int talsh_data_kind> struct TensorDataType{using value = void;};
template <> struct TensorDataType<R4>{using value = float;};
template <> struct TensorDataType<R8>{using value = double;};
template <> struct TensorDataType<C4>{using value = std::complex<float>;};
template <> struct TensorDataType<C8>{using value = std::complex<double>;};

//Helper functions:

double realPart(float number){return static_cast<double>(number);}
double realPart(double number){return number;}
double realPart(std::complex<float> number){return static_cast<double>(number.real());}
double realPart(std::complex<double> number){return number.real();}
double imagPart(float number){return 0.0f;}
double imagPart(double number){return 0.0;}
double imagPart(std::complex<float> number){return static_cast<double>(number.imag());}
double imagPart(std::complex<double> number){return number.imag();}

//Classes:

/** Dense local tensor **/
class Tensor{

public:

 /** Ctor **/
 template <typename T>
 Tensor(const std::initializer_list<std::size_t> signature, //tensor signature (identifier): signature[0:rank-1]
        const std::initializer_list<int> dims,              //tensor dimension extents: dims[0:rank-1]
        const T init_val);                                  //scalar initialization value (its type will define tensor element data kind)

 /** Ctor **/
 template <typename T>
 Tensor(const std::initializer_list<std::size_t> signature, //tensor signature (identifier): signature[0:rank-1]
        const std::initializer_list<int> dims,              //tensor dimension extents: dims[0:rank-1]
        T * ext_mem,                                        //pointer to an external memory storage where the tensor body will reside
        const T * init_val);                                //optional scalar initialization value (provide nullptr if not needed)

 /** Copy ctor **/
 Tensor(const Tensor & tensor) = delete;

 /** Copy assignment **/
 Tensor & operator=(const Tensor & tensor) = delete;

 /** Dtor **/
 ~Tensor();

 /** Use count increment/decrement. **/
 Tensor & operator++(); //increments tensor use count
 Tensor & operator--(); //decrements tensor use count

 /** Synchronizes the tensor presence on a given device.
     Returns TRUE on success, FALSE if an active write task
     on this tensor has failed to complete successfully. **/
 bool sync(const int device_kind = DEV_HOST, //in: device kind
           const int device_id = 0,          //in: specific device of the given kind which the synchronization is done for
           void * dev_mem = nullptr);        //in: optional pointer to that device's client memory where the tensor data should go

 /** Performs a tensor contraction of two tensors and accumulates the result into the current tensor. **/
 template <typename T>
 void contraction(TensorTask & task_handle,               //out: task handle associated with this operation
                  const std::string & pattern,            //in: contraction pattern string
                  Tensor & left,                          //in: left tensor
                  Tensor & right,                         //in: right tensor
                  const int device_kind = DEV_HOST,       //in: execution device kind
                  const int device_id = 0,                //in: execution device id
                  const T factor = TensorData<T>::unity); //in: alpha factor

 /** Prints the tensor. **/
 void print() const;

private:

 talsh_tens_t * get_talsh_tensor_ptr();
 bool complete_write_task();

 std::initializer_list<std::size_t> signature_; //tensor signature (unique integer multi-index identifier)
 talsh_tens_t tensor_;                          //TAL-SH tensor block
 TensorTask * write_task_;                      //non-owning pointer to the task handle for the current asynchronous operation updating the tensor, if any
 int used_;                                     //number of unfinished (asynchronous) TAL-SH operations that are currently using the tensor
};

//Namespace API:

void initialize(std::size_t * host_buffer_size = nullptr); //in: desired host buffer size; out: actual host buffer size
void shutdown();

template <typename T>
void gemm(Tensor & result, //out: result tensor
          Tensor & left,   //in: left tensor
          Tensor & right,  //in: right tensor
          const T factor); //in: alpha factor

#if 0
template <typename T>
Tensor gemm(Tensor & left,   //in: left tensor
            Tensor & right,  //in: right tensor
            const T factor); //in: alpha factor
#endif

} //namespace talsh

//Template definition:
#include "talshxx.cpp"

#endif //_TALSHXX_HPP
