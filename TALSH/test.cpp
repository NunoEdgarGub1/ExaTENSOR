/** TALSH::C/C++ API testing.

!Copyright (C) 2014-2018 Dmitry I. Lyakh (Liakh)
!Copyright (C) 2014-2018 Oak Ridge National Laboratory (UT-Battelle)

!This file is part of ExaTensor.

!ExaTensor is free software: you can redistribute it and/or modify
!it under the terms of the GNU Lesser General Public License as published
!by the Free Software Foundation, either version 3 of the License, or
!(at your option) any later version.

!ExaTensor is distributed in the hope that it will be useful,
!but WITHOUT ANY WARRANTY; without even the implied warranty of
!MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
!GNU Lesser General Public License for more details.

!You should have received a copy of the GNU Lesser General Public License
!along with ExaTensor. If not, see <http://www.gnu.org/licenses/>.
**/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#include "talsh.h"

#ifdef __cplusplus
#include <iostream>
#include <memory>
#include <string>
#include <complex>
#include "talshxx.hpp"
#endif

#ifdef __cplusplus
extern "C"{
#endif
void test_talsh_c(int * ierr);
void test_talsh_cxx(int * ierr);
void test_talsh_qc(int * ierr);
void test_nwchem_c(int * ierr);
#ifndef NO_GPU
void test_nvtal_c(int * ierr);
#endif
#ifdef __cplusplus
}
#endif


void test_talsh_c(int * ierr)
{
 const int VDIM_SIZE=40; //virtual
 const int ODIM_SIZE=20; //occupied
 int errc;
 //size_t host_buffer_size=TALSH_NO_HOST_BUFFER;
 size_t host_buffer_size = 1024*1024*1024; //bytes
 int gpu_list[MAX_GPUS_PER_NODE];

 *ierr=0;

//Query the total number of NVIDIA GPU on node:
 int ngpu;
 errc=talshGetDeviceCount(DEV_NVIDIA_GPU,&ngpu); if(errc){*ierr=1; return;};
 printf(" Number of NVIDIA GPU found on node = %d\n",ngpu);

//Initialize TAL-SH (with a negligible Host buffer since we will use external memory):
 int host_arg_max;
 for(int i=0; i<ngpu; ++i) gpu_list[i]=i; //list of NVIDIA GPU devices to use in this process
 errc=talshInit(&host_buffer_size,&host_arg_max,ngpu,gpu_list,0,NULL,0,NULL);
 printf(" TAL-SH has been initialized: Status %d: Host buffer size = %lu \n",errc,host_buffer_size); if(errc){*ierr=2; return;};

//Allocate three tensor blocks in Host memory outside of TAL-SH (external application):
 //Tensor block 0:
 int trank0 = 4; //tensor block rank
 const int dims0[] = {VDIM_SIZE,VDIM_SIZE,ODIM_SIZE,ODIM_SIZE}; //tensor block dimension extents
 //size_t vol0 = 1; for(int i=0; i<trank0; ++i) vol0*=(size_t)dims0[i]; //tensor block volume (number of elements)
 //double * tblock0 = (double*)malloc(vol0*sizeof(double)); //tensor block body (tensor elements)
 //for(size_t l=0; l<vol0; ++l) tblock0[l]=0.0; //initialize it to zero
 //Tensor block 1:
 int trank1 = 4; //tensor block rank
 const int dims1[] = {VDIM_SIZE,VDIM_SIZE,VDIM_SIZE,VDIM_SIZE}; //tensor block dimension extents
 //size_t vol1 = 1; for(int i=0; i<trank1; ++i) vol1*=(size_t)dims1[i]; //tensor block volume (number of elements)
 //double * tblock1 = (double*)malloc(vol1*sizeof(double)); //tensor block body (tensor elements)
 //for(size_t l=0; l<vol1; ++l) tblock1[l]=0.01; //initialize it to something
 //Tensor block 2:
 int trank2 = 4; //tensor block rank
 const int dims2[] = {ODIM_SIZE,VDIM_SIZE,ODIM_SIZE,VDIM_SIZE}; //tensor block dimension extents
 //size_t vol2 = 1; for(int i=0; i<trank2; ++i) vol2*=(size_t)dims2[i]; //tensor block volume (number of elements)
 //double * tblock2 = (double*)malloc(vol2*sizeof(double)); //tensor block body (tensor elements)
 //for(size_t l=0; l<vol2; ++l) tblock2[l]=0.001; //initialize it to something
 //printf(" Three external tensor blocks have been allocated by application\n");

//Register external tensor blocks with TAL-SH (in Host memory):
 //Tensor block 0:
 talsh_tens_t tens0; //declare a TAL-SH tensor block
 errc = talshTensorClean(&tens0); if(errc){*ierr=3; return;}; //clean TAL-SH tensor block object (default ctor)
 errc = talshTensorConstruct(&tens0,R8,trank0,dims0,talshFlatDevId(DEV_HOST,0),NULL,-1,NULL,0.0); //construct tensor block in Host buffer
 //errc = talshTensorConstruct(&tens0,R8,trank0,dims0,talshFlatDevId(DEV_HOST,0),(void*)tblock0); //register tensor block with external memory
 if(errc){*ierr=4; return;};
 size_t vol0 = talshTensorVolume(&tens0);
 //Tensor block 1:
 talsh_tens_t tens1; //declare a TAL-SH tensor block
 errc = talshTensorClean(&tens1); if(errc){*ierr=5; return;}; //clean TAL-SH tensor block object (default ctor)
 errc = talshTensorConstruct(&tens1,R8,trank1,dims1,talshFlatDevId(DEV_HOST,0),NULL,-1,NULL,0.001); //construct tensor block in Host buffer
 //errc = talshTensorConstruct(&tens1,R8,trank1,dims1,talshFlatDevId(DEV_HOST,0),(void*)tblock1); //register tensor block with external memory
 if(errc){*ierr=6; return;};
 size_t vol1 = talshTensorVolume(&tens1);
 //Tensor block 2:
 talsh_tens_t tens2; //declare a TAL-SH tensor block
 errc = talshTensorClean(&tens2); if(errc){*ierr=7; return;}; //clean TAL-SH tensor block object (default ctor)
 errc = talshTensorConstruct(&tens2,R8,trank2,dims2,talshFlatDevId(DEV_HOST,0),NULL,-1,NULL,0.01); //construct tensor block in Host buffer
 //errc=talshTensorConstruct(&tens2,R8,trank2,dims2,talshFlatDevId(DEV_HOST,0),(void*)tblock2); //register tensor block with external memory
 if(errc){*ierr=8; return;};
 size_t vol2 = talshTensorVolume(&tens2);
 double gflops = (sqrt(((double)(vol0))*((double)(vol1))*((double)(vol2)))*2.0)/1e9; //total number of floating point operations (GFlops)
 double theor_norm1 = gflops * 0.01 * 0.001 * 1e9;
 printf(" Three TAL-SH tensor blocks have been constructed: Volumes: %lu, %lu, %lu: GFlops = %f\n",vol0,vol1,vol2,gflops);

//Declare a TAL-SH task handle:
 talsh_task_t task0; //declare a TAL-SH task handle
 errc=talshTaskClean(&task0); //clean TAL-SH task handle object to an empty state
 if(errc){*ierr=9; return;};

//Execute a tensor contraction either on CPU (synchronously) or GPU (asynchronously):
#ifndef NO_GPU
 int dev_kind = DEV_NVIDIA_GPU; //NVIDIA GPU devices
 int dev_num = 0; //specific device number (any from gpu_list[])
#else
 int dev_kind = DEV_HOST; //CPU Host (multicore)
 int dev_num = 0; //CPU Host is always a single device (but multicore)
#endif
 //Schedule:
 clock_t tms = clock();
 errc=talshTensorContract("D(a,b,i,j)+=L(c,b,d,a)*R(j,d,i,c)",&tens0,&tens1,&tens2,2.0,0.0,dev_num,dev_kind,COPY_MTT,&task0);
 printf(" Tensor contraction has been scheduled for execution: Status %d\n",errc); if(errc){*ierr=10; return;};
 //Test for completion:
 int sts,done=NOPE;
 while(done != YEP && errc == TALSH_SUCCESS){done=talshTaskComplete(&task0,&sts,&errc);}
 double tm = ((double)(clock() - tms))/CLOCKS_PER_SEC;
 if(errc == TALSH_SUCCESS){
  printf(" Tensor contraction has completed successfully: Status %d: Time %f sec\n",sts,tm);
 }else{
  printf(" Tensor contraction has failed: Status %d: Error %d\n",sts,errc);
  *ierr=11; return;
 }
 //Timing:
 double total_time;
 errc=talshTaskTime(&task0,&total_time); if(errc){*ierr=12; return;};
 printf(" Tensor contraction total time = %f: GFlop/s = %f\n",total_time,gflops/total_time);
 //Destruct the task handle:
 errc=talshTaskDestruct(&task0); if(errc){*ierr=13; return;};
#ifndef NO_GPU
 //If executed on GPU, COPY_MTT parameter in the tensor contraction call above means that the
 //destination tensor image was moved to GPU device (letter M means MOVE).
 //So, let's move it back to Host (to a user-specified memory location):
 errc=talshTensorPlace(&tens0,0,DEV_HOST,NULL,COPY_M); //this will move the resulting tensor block back to Host (letter M means MOVE)
 if(errc){*ierr=14; return;};
#endif
 printf(" Tensor result was moved back to Host: Norm1 = %E: Correct = %E\n",talshTensorImageNorm1_cpu(&tens0),theor_norm1);

//Unregister tensor blocks with TAL-SH:
 errc=talshTensorDestruct(&tens2); if(errc){*ierr=15; return;};
 errc=talshTensorDestruct(&tens1); if(errc){*ierr=16; return;};
 errc=talshTensorDestruct(&tens0); if(errc){*ierr=17; return;};
 printf(" Three external tensor blocks have been unregistered with TAL-SH\n");

//Free external memory (local tensor blocks):
 //free(tblock2); tblock2=NULL;
 //free(tblock1); tblock1=NULL;
 //free(tblock0); tblock0=NULL;

//Shutdown TAL-SH:
 errc=talshShutdown();
 printf(" TAL-SH has been shut down: Status %d\n",errc); if(errc){*ierr=18; return;};

 return;
}


#ifdef __cplusplus
void test_talsh_cxx(int * ierr)
{
 const int VDIM=40; //virtual dimension size
 const int ODIM=20; //occupied dimension size

 *ierr=0;
 //Initialize:
 talsh::initialize();
 //Tensor contraction (brackets are needed to push talsh::shutdown() out of scope):
 {
  //Create destination tensor:
  talsh::Tensor dtens({1,2,3,4},{VDIM,VDIM,ODIM,ODIM},0.0);
  dtens.print(); //debug
  //Create left tensor:
  talsh::Tensor ltens({5,6,7,8},{ODIM,VDIM,ODIM,VDIM},0.01);
  //Create right tensor:
  talsh::Tensor rtens({9,10,11,12},{VDIM,VDIM,VDIM,VDIM},0.001);
  //Perform tensor contraction:
  talsh::TensorTask task_hl;
  *ierr = dtens.contractAccumulate(&task_hl,std::string("D(a,b,c,d)+=L(d,i,c,j)*R(j,b,i,a)"),ltens,rtens,DEV_HOST,0,0.5);
  bool done = dtens.sync();
  std::cout << "Tensor contraction completion status = " << done << "; Error " << *ierr << std::endl;
  dtens.print(); //debug
 }
 //Matrix multiplication (brackets are needed to push talsh::shutdown() out of scope):
 if(*ierr == 0){
  //Create destination tensor:
  talsh::Tensor dtens({1,2,3,4},{VDIM,VDIM,ODIM,ODIM},0.0);
  dtens.print(); //debug
  //Create left tensor:
  talsh::Tensor ltens({5,6,7,8},{VDIM,VDIM,VDIM,VDIM},0.01);
  //Create right tensor:
  talsh::Tensor rtens({9,10,11,12},{VDIM,VDIM,ODIM,ODIM},0.001);
  //Perform matrix multiplication:
  talsh::TensorTask task_hl;
  *ierr = dtens.multiplyAccumulate(&task_hl,ltens,rtens,DEV_HOST,0,0.5);
  bool done = dtens.sync();
  std::cout << "Matrix multiplication completion status = " << done << "; Error " << *ierr << std::endl;
  dtens.print(); //debug
 }
 //Shutdown:
 talsh::shutdown();
 return;
}


void test_talsh_qc(int * ierr)
{
 using ComplexType = std::complex<double>;

 constexpr int NUM_CONTRACTIONS_CPU = 2; //number of tensor contractions to be executed by TAL-SH on multicore CPU
 constexpr int NUM_CONTRACTIONS_GPU = 4; //number of tensor contractions to be executed by TAL-SH on multiple GPU
 constexpr int NUM_CONTRACTIONS = NUM_CONTRACTIONS_CPU + NUM_CONTRACTIONS_GPU; //number of tensor contractions to be executed by TAL-SH

 *ierr=0;

 //QC application tensor class:
 class QCTensor{
  public:

  unsigned int getRank()
  {
   return static_cast<unsigned int>(shape_.size());
  }

  std::size_t getVolume()
  {
   std::size_t tvol = 1;
   for(const auto & dim: shape_) tvol*=static_cast<std::size_t>(dim);
   return tvol;
  }

  const std::vector<int> & getShape()
  {
   return shape_;
  }

  ComplexType * getDataPtr()
  {
   return tdata_;
  }

  QCTensor(const std::vector<int> & dims):
   shape_(dims)
  {
   std::size_t tvol = this->getVolume();
   tdata_ = new ComplexType[tvol];
  }

  QCTensor(const QCTensor & another) = delete;
  QCTensor & operator=(const QCTensor & another) = delete;

  QCTensor(QCTensor && another)
  {
   if(this != &another){
    this->shape_ = another.shape_;
    this->tdata_ = another.tdata_;
    another.shape_.clear();
    another.tdata_ = nullptr;
   }
  }

  QCTensor & operator=(QCTensor && another){
   if(this != &another){
    this->shape_ = another.shape_;
    this->tdata_ = another.tdata_;
    another.shape_.clear();
    another.tdata_ = nullptr;
   }
   return *this;
  }

  ~QCTensor()
  {
   if(tdata_ != nullptr){
    //std::cout << "Deleting tensor data " << (void*)tdata_ << std::endl; //debug
    delete [] tdata_;
   }
  };

  private:

  std::vector<int> shape_;
  ComplexType * tdata_;
 };

 //TAL-SH tensor contraction specification class:
 class TensContraction{
  public:

  TensContraction(const std::string & pattern,
                  talsh::Tensor * tens0,
                  talsh::Tensor * tens1,
                  talsh::Tensor * tens2,
                  ComplexType alpha = ComplexType{1.0f,0.0f}):
   index_pattern_(pattern),tensor0_(tens0),tensor1_(tens1),tensor2_(tens2),alpha_(alpha)
  {
  }

  TensContraction(const TensContraction & another) = default;
  TensContraction & operator=(const TensContraction & another) = default;
  TensContraction(TensContraction && another) = default;
  TensContraction & operator=(TensContraction && another) = default;
  ~TensContraction() = default;

  int execute(int device_kind, int device_id, talsh::TensorTask & task_hl)
  {
   int ierr = tensor0_->contractAccumulate(&task_hl,index_pattern_,*tensor1_,*tensor2_,device_kind,device_id,alpha_);
   return ierr;
  }

  bool sync()
  {
   bool done = tensor0_->sync();
   return done;
  }

  private:

  std::string index_pattern_;
  talsh::Tensor * tensor0_;
  talsh::Tensor * tensor1_;
  talsh::Tensor * tensor2_;
  ComplexType alpha_;
 };

 //QC application initializes TAL-SH:
 talsh::initialize();
 std::cout << " QC application initialized TAL-SH" << std::endl;

 //QC application allocates NUM_CONTRACTIONS*3 tensors (QCTensor):
 std::vector<QCTensor> tensors;
 for(int i = 0; i < NUM_CONTRACTIONS*3; ++i){
  tensors.emplace_back(QCTensor(std::vector<int>{32,32,32,32}));
  std::cout << " QC application allocated tensor " << i << " of volume " << tensors[i].getVolume() << std::endl;
 }

 //QC application enters an inner scope to perform tensor operations via TAL-SH:
 std::cout << " QC application entered TAL-SH execution" << std::endl;
 {
  //QC application registers its tensors with TAL-SH (NUM_CONTRACTIONS*3 tensors total):
  std::vector<talsh::Tensor> talsh_tensors;
  for(int i = 0; i < NUM_CONTRACTIONS*3; ++i){
   talsh_tensors.emplace_back(talsh::Tensor(tensors[i].getShape(),tensors[i].getDataPtr()));
   std::cout << "  QC application constructed TAL-SH tensor " << i << ":" << std::endl; //talsh_tensors[i].print();
  }

  //QC application constructs a list of tensor contractions for CPU and GPU:
  std::vector<TensContraction> contractions_cpu; //tensor contractions to be executed on CPU
  std::vector<TensContraction> contractions_gpu; //tensor contractions to be executed on GPU
  // For CPU:
  for(int i = 0; i < NUM_CONTRACTIONS_CPU; ++i){
   int base_tensor = i*3;
   contractions_cpu.emplace_back(TensContraction("D(a,b,c,d)+=L(c,i,b,j)*R(d,j,a,i)",
                                                 &(talsh_tensors[base_tensor+0]),
                                                 &(talsh_tensors[base_tensor+1]),
                                                 &(talsh_tensors[base_tensor+2])));
  }
  std::cout << "  QC application placed " << NUM_CONTRACTIONS_CPU << " tensor contractions into the CPU queue" << std::endl;
  // For CPU:
  for(int i = NUM_CONTRACTIONS_CPU; i < NUM_CONTRACTIONS_CPU + NUM_CONTRACTIONS_GPU; ++i){
   int base_tensor = i*3;
   contractions_gpu.emplace_back(TensContraction("D(a,b,c,d)+=L(c,i,b,j)*R(d,j,a,i)",
                                                 &(talsh_tensors[base_tensor+0]),
                                                 &(talsh_tensors[base_tensor+1]),
                                                 &(talsh_tensors[base_tensor+2])));
  }
  std::cout << "  QC application placed " << NUM_CONTRACTIONS_GPU << " tensor contractions into the GPU queue" << std::endl;

  //QC application executes tensor contractions on GPU via TAL-SH:
  for(auto & contraction: contractions_gpu){
   talsh::TensorTask task_hl;
   contraction.execute(DEV_NVIDIA_GPU,0,task_hl);
   while(!contraction.sync());
  }
  std::cout << "  QC application executed " << NUM_CONTRACTIONS_GPU << " tensor contractions from the GPU queue" << std::endl;

  //QC application executes tensor contractions on CPU via TAL-SH:
  for(auto & contraction: contractions_cpu){
   talsh::TensorTask task_hl;
   contraction.execute(DEV_HOST,0,task_hl);
   while(!contraction.sync());
  }
  std::cout << "  QC application executed " << NUM_CONTRACTIONS_CPU << " tensor contractions from the CPU queue" << std::endl;

 }
 std::cout << " QC application exited TAL-SH execution" << std::endl;

 //QC application deallocates tensors (QCTensor);
 tensors.clear();
 std::cout << " QC application deallocated all its tensors" << std::endl;

 //QC application shuts down TAL-SH:
 talsh::shutdown();
 std::cout << " QC application shut down TAL-SH" << std::endl;

 return;
}
#endif //__cplusplus


void test_nwchem_c(int * ierr)
{
 const int VDIM_SIZE=5; //virtual
 const int ODIM_SIZE=2; //occupied
 int errc;
 time_t tm;
 //size_t host_buffer_size=TALSH_NO_HOST_BUFFER;
 size_t host_buffer_size = 1024*1024*1024; //bytes
 int gpu_list[MAX_GPUS_PER_NODE];

 *ierr=0;
 srand((unsigned)time(&tm));

//Query the total number of NVIDIA GPU on node:
 int ngpu;
 errc=talshGetDeviceCount(DEV_NVIDIA_GPU,&ngpu); if(errc){*ierr=1; return;};
 printf(" Number of NVIDIA GPU found on node = %d\n",ngpu);

//Initialize TAL-SH (with a negligible Host buffer since we will use external memory):
 int host_arg_max;
 for(int i=0; i<ngpu; ++i) gpu_list[i]=i; //list of NVIDIA GPU devices to use in this process
 errc=talshInit(&host_buffer_size,&host_arg_max,ngpu,gpu_list,0,NULL,0,NULL);
 printf(" TAL-SH has been initialized: Status %d: Host buffer size = %lu \n",errc,host_buffer_size); if(errc){*ierr=2; return;};

//Allocate three tensor blocks in Host memory outside of TAL-SH (external application):
 //Tensor block 0:
 int trank0 = 2; //tensor block rank
 const int dims0[] = {ODIM_SIZE,VDIM_SIZE}; //tensor block dimension extents
 size_t vol0 = 1; for(int i=0; i<trank0; ++i) vol0*=(size_t)dims0[i]; //tensor block volume (number of elements)
 double * tblock0 = (double*)malloc(vol0*sizeof(double)); //tensor block body (tensor elements)
 for(size_t l=0; l<vol0; ++l) tblock0[l]=0.0; //initialize it to zero
 //Tensor block 1:
 int trank1 = 2; //tensor block rank
 const int dims1[] = {VDIM_SIZE,ODIM_SIZE}; //tensor block dimension extents
 size_t vol1 = 1; for(int i=0; i<trank1; ++i) vol1*=(size_t)dims1[i]; //tensor block volume (number of elements)
 double * tblock1 = (double*)malloc(vol1*sizeof(double)); //tensor block body (tensor elements)
 //for(size_t l=0; l<vol1; ++l) tblock1[l]=0.01; //initialize it to value
 for(size_t l=0; l<vol1; ++l) tblock1[l]=1000000.0/((double)(rand()+1)); //initialize it to random
 //Tensor block 2:
 int trank2 = 4; //tensor block rank
 const int dims2[] = {ODIM_SIZE,ODIM_SIZE,VDIM_SIZE,VDIM_SIZE}; //tensor block dimension extents
 size_t vol2 = 1; for(int i=0; i<trank2; ++i) vol2*=(size_t)dims2[i]; //tensor block volume (number of elements)
 double * tblock2 = (double*)malloc(vol2*sizeof(double)); //tensor block body (tensor elements)
 //for(size_t l=0; l<vol2; ++l) tblock2[l]=0.001; //initialize it to value
 for(size_t l=0; l<vol2; ++l) tblock2[l]=100000.0/((double)(rand()+1)); //initialize it to random
 //printf(" Three external tensor blocks have been allocated by application\n");

//Register external tensor blocks with TAL-SH (in Host memory):
 //Tensor block 0:
 talsh_tens_t tens0; //declare a TAL-SH tensor block
 errc = talshTensorClean(&tens0); if(errc){*ierr=3; return;}; //clean TAL-SH tensor block object (default ctor)
 errc = talshTensorConstruct(&tens0,R8,trank0,dims0,talshFlatDevId(DEV_HOST,0),(void*)tblock0); //register tensor block with external memory
 if(errc){*ierr=4; return;};
 //vol0 = talshTensorVolume(&tens0);
 //Tensor block 1:
 talsh_tens_t tens1; //declare a TAL-SH tensor block
 errc = talshTensorClean(&tens1); if(errc){*ierr=5; return;}; //clean TAL-SH tensor block object (default ctor)
 errc = talshTensorConstruct(&tens1,R8,trank1,dims1,talshFlatDevId(DEV_HOST,0),(void*)tblock1); //register tensor block with external memory
 if(errc){*ierr=6; return;};
 //vol1 = talshTensorVolume(&tens1);
 //Tensor block 2:
 talsh_tens_t tens2; //declare a TAL-SH tensor block
 errc = talshTensorClean(&tens2); if(errc){*ierr=7; return;}; //clean TAL-SH tensor block object (default ctor)
 errc=talshTensorConstruct(&tens2,R8,trank2,dims2,talshFlatDevId(DEV_HOST,0),(void*)tblock2); //register tensor block with external memory
 if(errc){*ierr=8; return;};
 //vol2 = talshTensorVolume(&tens2);

 printf(" Left tensor norm1        = %e\n",talshTensorImageNorm1_cpu(&tens1));
 printf(" Right tensor norm1       = %e\n",talshTensorImageNorm1_cpu(&tens2));

//Execute a tensor contraction on CPU:
 errc=talshTensorContract("D(a,b)+=L(c,d)*R(d,a,b,c)",&tens0,&tens1,&tens2,-2.0,0.0,0,DEV_HOST);
 if(errc == TALSH_SUCCESS){
  printf(" Tensor contraction has completed successfully\n");
 }else{
  printf(" Tensor contraction has failed: Error %d\n",errc);
  *ierr=9; return;
 }
 printf(" Destination tensor norm1 = %e\n",talshTensorImageNorm1_cpu(&tens0));

//Execute a tensor contraction on CPU again:
 errc=talshTensorContract("D(a,b)+=L(c,d)*R(d,a,b,c)",&tens0,&tens1,&tens2,1.0,0.0,0,DEV_HOST);
 if(errc == TALSH_SUCCESS){
  printf(" Tensor contraction has completed successfully\n");
 }else{
  printf(" Tensor contraction has failed: Error %d\n",errc);
  *ierr=9; return;
 }
 printf(" Destination tensor norm1 = %e\n",talshTensorImageNorm1_cpu(&tens0));

//Verify the correctness of the result:
 for(int ib = 0; ib < dims0[1]; ++ib){
  for(int ia = 0; ia < dims0[0]; ++ia){
   for(int id = 0; id < dims1[1]; ++id){
    for(int ic = 0; ic < dims1[0]; ++ic){
     tblock0[ia + ib*dims0[0]] += tblock1[ic + id*dims1[0]] * tblock2[id + ia*dims2[0] + ib*dims2[1]*dims2[0] + ic*dims2[2]*dims2[1]*dims2[0]];
    }
   }
  }
 }
 printf(" Destination tensor norm1 error = %e\n",talshTensorImageNorm1_cpu(&tens0));

//Unregister tensor blocks with TAL-SH:
 errc=talshTensorDestruct(&tens2); if(errc){*ierr=10; return;};
 errc=talshTensorDestruct(&tens1); if(errc){*ierr=11; return;};
 errc=talshTensorDestruct(&tens0); if(errc){*ierr=12; return;};
 printf(" Three external tensor blocks have been unregistered with TAL-SH\n");

//Free external memory (local tensor blocks):
 free(tblock2); tblock2=NULL;
 free(tblock1); tblock1=NULL;
 free(tblock0); tblock0=NULL;

//Shutdown TAL-SH:
 errc=talshShutdown();
 printf(" TAL-SH has been shut down: Status %d\n",errc); if(errc){*ierr=13; return;};
 return;
}


#ifndef NO_GPU
void test_nvtal_c(int * ierr)
{
 int host_arg_max,errc;
 size_t host_buf_size;
 cudaTask_t *tsk0,*tsk1; //CUDA tasks (pointers)
 tensBlck_t *t0,*t1,*t2; //tensor blocks (pointers)
 int r0=4,r1=4,r2=4; //tensor block ranks
 int dims0[]={40,40,40,40}; //tensor block 0 dimensions
 int dims1[]={40,40,40,40}; //tensor block 1 dimensions
 int dims2[]={40,40,40,40}; //tensor block 2 dimensions
 float tm_tot,tm_in,tm_out,tm_comp;

 *ierr=0;
//Initialize Host/GPU argument buffers and NV-TAL:
 host_buf_size=1000000000;
 printf(" Initializing NV-TAL ...");
 errc=arg_buf_allocate(&host_buf_size,&host_arg_max,0,0);
 printf(" Status %d: Host argument buffer size = %lu; Max args in HAB = %d\n",errc,host_buf_size,host_arg_max);
 if(errc){*ierr=1; return;}

//Create tensor blocks:
 //Tensor block 0:
 printf(" Creating tensor block 0 ...");
 errc=tensBlck_create(&t0);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 printf(" Constructing shape of tensor block 0 ...");
 errc=tensBlck_construct(t0,YEP,r0,dims0);
 printf(" Status %d: Tensor block volume = %lu:",errc,tensBlck_volume(t0)); if(errc){*ierr=1; return;}
 printf(" Attaching body to tensor block 0 ...");
 errc=tensBlck_attach_body(t0,R8);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 //Tensor block 1:
 printf(" Creating tensor block 1 ...");
 errc=tensBlck_create(&t1);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 printf(" Constructing shape of tensor block 1 ...");
 errc=tensBlck_construct(t1,YEP,r1,dims1);
 printf(" Status %d: Tensor block volume = %lu:",errc,tensBlck_volume(t1)); if(errc){*ierr=1; return;}
 printf(" Attaching body to tensor block 1 ...");
 errc=tensBlck_attach_body(t1,R8);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 //Tensor block 2:
 printf(" Creating tensor block 2 ...");
 errc=tensBlck_create(&t2);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 printf(" Constructing shape of tensor block 2 ...");
 errc=tensBlck_construct(t2,YEP,r2,dims2);
 printf(" Status %d: Tensor block volume = %lu:",errc,tensBlck_volume(t2)); if(errc){*ierr=1; return;}
 printf(" Attaching body to tensor block 2 ...");
 errc=tensBlck_attach_body(t2,R8);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}

//Initialize tensor blocks to value (on Host):
 //Tensor block 0:
 printf(" Initializing tensor block 0 ...");
 errc=tensBlck_init_host(t0,0.0);
 printf(" Status %d:",errc); if(errc){*ierr=1; return;}
 printf(" Squared 2-norm = %e\n",tensBlck_norm2_host(t0));
 //Tensor block 1:
 printf(" Initializing tensor block 1 ...");
 errc=tensBlck_init_host(t1,0.01);
 printf(" Status %d:",errc); if(errc){*ierr=1; return;}
 printf(" Squared 2-norm = %e\n",tensBlck_norm2_host(t1));
 //Tensor block 2:
 printf(" Initializing tensor block 2 ...");
 errc=tensBlck_init_host(t2,0.001);
 printf(" Status %d:",errc); if(errc){*ierr=1; return;}
 printf(" Squared 2-norm = %e\n",tensBlck_norm2_host(t2));

//Create CUDA tasks:
 printf(" Creating a CUDA task ...");
 errc=cuda_task_create(&tsk0);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 printf(" Creating a CUDA task ...");
 errc=cuda_task_create(&tsk1);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}

//Tensor contraction on GPU:
 int cptrn0[]={4,3,-3,-4,2,1,-3,-4}; //tensor contraction pattern
 //Schedule a tensor contraction task on GPU:
 printf(" Scheduling a tensor contraction on GPU ...");
 errc=gpu_tensor_block_contract_dlf(cptrn0,t1,t2,t0,COPY_TTT,tsk0);
 cuda_task_print(tsk0);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 //Wait until task completion:
 printf(" Waiting upon completion ...");
 errc=cuda_task_wait(tsk0);
 printf(" Status %d",errc); if(errc != CUDA_TASK_COMPLETED){*ierr=1; return;}
 tm_tot=cuda_task_time(tsk0,&tm_in,&tm_out,&tm_comp); //task timing
 printf(": Timings (total,in,out,comp): %f %f %f %f\n",tm_tot,tm_in,tm_out,tm_comp);
 //Print the 2-norm of the destination tensor:
 printf(" Destination tensor squared 2-norm = %e\n",tensBlck_norm2_host(t0));

//Destroy CUDA tasks:
 printf(" Destroying a CUDA task ...");
 errc=cuda_task_destroy(tsk1);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 printf(" Destroying a CUDA task ...");
 errc=cuda_task_destroy(tsk0);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}

//Destroy tensor blocks:
 //Tensor block 2:
 printf(" Destroying tensor block 2 ...");
 errc=tensBlck_destroy(t2);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 //Tensor block 1:
 printf(" Destroying tensor block 1 ...");
 errc=tensBlck_destroy(t1);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}
 //Tensor block 0:
 printf(" Destroying tensor block 0 ...");
 errc=tensBlck_destroy(t0);
 printf(" Status %d\n",errc); if(errc){*ierr=1; return;}

//NV-TAL statistics:
 printf(" NV-TAL statistics:");
 gpu_print_stats();

//Free Host/GPU argument buffers and shutdown NV-TAL:
 printf(" Shutting down NV-TAL ...");
 errc=arg_buf_deallocate(0,0);
 printf(" Status: %d\n",errc); if(errc){*ierr=1; return;}
 return;
}
#endif //NO_GPU
