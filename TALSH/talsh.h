/** ExaTensor::TAL-SH: Device-unified user-level API header.
REVISION: 2016/05/23

Copyright (C) 2014-2016 Dmitry I. Lyakh (Liakh)
Copyright (C) 2014-2016 Oak Ridge National Laboratory (UT-Battelle)

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

#ifndef _TALSH_H
#define _TALSH_H

#include "tensor_algebra.h"

//TAL-SH PARAMETERS:
#define TALSH_MAX_DEV_PRESENT 16 //max number of on-node devices the tensor block can be simultaneously present on

//TAL-SH ERROR CODES (keep consistent with "talshf.F90"):
#define TALSH_SUCCESS 0
#define TALSH_FAILURE -666
#define TALSH_NOT_AVAILABLE -888
#define TALSH_NOT_IMPLEMENTED -999
#define TALSH_NOT_INITIALIZED 1000000
#define TALSH_ALREADY_INITIALIZED 1000001
#define TALSH_INVALID_ARGS 1000002
#define TALSH_INTEGER_OVERFLOW 1000003
#define TALSH_OBJECT_NOT_EMPTY 1000004
#define TALSH_OBJECT_IS_EMPTY 1000005
#define TALSH_IN_PROGRESS 1000006
#define TALSH_NOT_ALLOWED 1000007
#define TALSH_LIMIT_EXCEEDED 1000008

//TAL-SH TASK STATUS:
#define TALSH_TASK_ERROR 1999999
#define TALSH_TASK_EMPTY 2000000
#define TALSH_TASK_SCHEDULED 2000001
#define TALSH_TASK_STARTED 2000002
#define TALSH_TASK_INPUT_READY 2000003
#define TALSH_TASK_OUTPUT_READY 2000004
#define TALSH_TASK_COMPLETED 2000005

//TAL-SH DATA TYPES:
// Interoperable tensor block:
typedef struct{
 talsh_tens_shape_t * shape_p; //shape of the tensor block
 talsh_dev_rsc_t * dev_rsc;    //list of device resources occupied by the tensor block body on each device
 int * data_kind;              //list of data kinds for each device location occupied by the tensor body {R4,R8,C4,C8}
 int * avail;                  //list of the data availability flags for each device location occupied by the tensor body
 int dev_rsc_len;              //capacity of .dev_rsc[], .data_kind[], .avail[]
 int ndev;                     //number of devices the tensor block body resides on: ndev <= dev_rsc_len
} talsh_tens_t;

// Tensor operation argument (auxiliary type):
typedef struct{
 talsh_tens_t * tens_p; //pointer to a tensor block
 int source_image;      //specific body image of that tensor block participating in the operation
} talshTensArg_t;

// Interoperable TAL-SH task handle:
typedef struct{
 void * task_p;    //pointer to the corresponding device-kind-specific task object
 int task_error;   //-1:undefined(task in progress or empty); 0:successfully completed; >0: error code
 int dev_kind;     //device kind (DEV_NULL: uninitalized)
 int data_kind;    //data kind {R4,R8,C4,C8}, NO_TYPE: uninitialized
 int coherence;    //coherence control (-1:undefined)
 int num_args;     //number of arguments participating in the tensor operation
 talshTensArg_t tens_args[MAX_TENSOR_OPERANDS]; //tensor arguments
 double data_vol;  //total data volume (information)
 double flops;     //number of floating point operations (information)
 double exec_time; //execution time in seconds (information)
} talsh_task_t;

//EXPORTED FUNCTIONS:
#ifdef __cplusplus
extern "C"{
#endif
// TAL-SH control API:
//  Initialize TAL-SH:
 int talshInit(size_t * host_buf_size,
               int * host_arg_max,
               int ngpus,
               int gpu_list[],
               int nmics,
               int mic_list[],
               int namds,
               int amd_list[]);
//  Shutdown TAL-SH:
 int talshShutdown();
//  Get the flat device Id:
 int talshFlatDevId(int dev_kind,
                    int dev_num);
//  Get the kind-specific device Id:
 int talshKindDevId(int dev_id,
                    int * dev_kind);
//  Query the state of a device:
 int talshDeviceState(int dev_num,
                      int dev_kind = DEV_NULL);
 int talshDeviceState_(int dev_num, int dev_kind);
//  Find the least busy device:
 int talshDeviceBusyLeast(int dev_kind = DEV_NULL);
 int talshDeviceBusyLeast_(int dev_kind);
//  Print TAL-SH statistics for specific devices:
 int talshStats(int dev_id = -1,
                int dev_kind = DEV_NULL);
 int talshStats_(int dev_id, int dev_kind);
// TAL-SH tensor block API:
//  Create an empty tensor block:
 int talshTensorCreate(talsh_tens_t ** tens_block);
//  Clean an undefined tensor block (default constructor):
 int talshTensorClean(talsh_tens_t * tens_block);
//  Check whether a tensor block is empty (clean):
 int talshTensorIsEmpty(const talsh_tens_t * tens_block);
//  Construct a tensor block:
 int talshTensorConstruct(talsh_tens_t * tens_block,
                          int data_kind,
                          int tens_rank,
                          const int tens_dims[],
                          int dev_id = 0,
                          void * ext_mem = NULL,
                          int in_hab = -1,
                          talsh_tens_init_i init_method = NULL,
                          double init_val_real = 0.0,
                          double init_val_imag = 0.0);
 int talshTensorConstruct_(talsh_tens_t * tens_block, int data_kind, int tens_rank, const int tens_dims[], int dev_id,
                           void * ext_mem, int in_hab, talsh_tens_init_i init_method, double init_val_real, double init_val_imag);
//  Destruct a tensor block:
 int talshTensorDestruct(talsh_tens_t * tens_block);
//  Destroy a tensor block:
 int talshTensorDestroy(talsh_tens_t * tens_block);
//  Get the tensor block volume (number of elements):
 size_t talshTensorVolume(const talsh_tens_t * tens_block);
//  Get the shape of the tensor block:
 int talshTensorShape(const talsh_tens_t * tens_block,
                      talsh_tens_shape_t * tens_shape);
//  Query the presence of the tensor block on device(s):
 int talshTensorPresence(const talsh_tens_t * tens_block,
                         int * ncopies,
                         int copies[],
                         int data_kinds[],
                         int dev_kind = DEV_NULL,
                         int dev_id = -1);
 int talshTensorPresence_(const talsh_tens_t * tens_block, int * ncopies, int copies[], int data_kinds[], int dev_kind, int dev_id);
 void talshTensorPrintInfo(const talsh_tens_t * tens_block);
// TAL-SH task API:
//  Create a clean (defined-empty) TAL-SH task:
 int talshTaskCreate(talsh_task_t ** talsh_task);
//  Clean an undefined TAL-SH task:
 int talshTaskClean(talsh_task_t * talsh_task);
//  Query whether a TAL-SH task is empty:
 int talshTaskIsEmpty(const talsh_task_t * talsh_task);
//  Destruct a TAL-SH task:
 int talshTaskDestruct(talsh_task_t * talsh_task);
//  Destroy a TAL-SH task:
 int talshTaskDestroy(talsh_task_t * talsh_task);
//  Get the id of the device the TAL-SH task is scheduled on:
 int talshTaskDevId(talsh_task_t * talsh_task,
                    int * dev_kind = NULL);
 int talshTaskDevId_(talsh_task_t * talsh_task, int * dev_kind);
//  Get the TAL-SH task status:
 int talshTaskStatus(talsh_task_t * talsh_task);
//  Check whether a TAL-SH task has completed:
 int talshTaskComplete(talsh_task_t * talsh_task,
                       int * stats,
                       int * ierr);
//  Wait upon a completion of a TAL-SH task:
 int talshTaskWait(talsh_task_t * talsh_task,
                   int * stats);
//  Wait upon a completion of multiple TAL-SH tasks:
 int talshTasksWait(int ntasks,
                    talsh_task_t talsh_tasks[],
                    int stats[]);
//  Get the TAL-SH task timings:
 int talshTaskTime(talsh_task_t * talsh_task,
                   double * total,
                   double * comput = NULL,
                   double * input = NULL,
                   double * output = NULL);
 int talshTaskTime_(talsh_task_t * talsh_task, double * total, double * comput, double * input, double * output);
//  Print TAL-SH task info:
 void talshTaskPrint(const talsh_task_t * talsh_task);
// TAL-SH tensor operations API:
//  Place a tensor block on a specific device:
 int talshTensorPlace(talsh_tens_t * tens,               //inout: tensor block
                      int dev_id,                        //in: device id (flat or kind-specific)
                      int dev_kind = DEV_NULL,           //in: device kind (if present, <dev_id> is kind-specific)
                      int copy_ctrl = COPY_M,            //in: copy control (COPY_X), defaults to COPY_M
                      talsh_task_t * talsh_task = NULL); //inout: TAL-SH task handle
 int talshTensorPlace_(talsh_tens_t * tens, int dev_id, int dev_kind, int copy_ctrl, talsh_task_t * talsh_task);
//  Discard a tensor block on a specific device:
 int talshTensorDiscard(talsh_tens_t * tens,      //inout: tensor block
                        int dev_id,               //in: device id (flat or kind-specific)
                        int dev_kind = DEV_NULL); //in: device kind (if present, <dev_id> is kind-specific)
 int talshTensorDiscard_(talsh_tens_t * tens, int dev_id, int dev_kind);
//  Tensor contraction:
 int talshTensorContract(const char * cptrn,                //in: C-string: symbolic contraction pattern, e.g. "D(a,b,c,d)+=L(c,i,j,a)*R(b,j,d,i)"
                         talsh_tens_t * dtens,              //inout: destination tensor block
                         talsh_tens_t * ltens,              //inout: left source tensor block
                         talsh_tens_t * rtens,              //inout: right source tensor block
                         int copy_ctrl = COPY_MTT,          //in: copy control (COPY_XXX), defaults to COPY_MTT
                         double scale_real = 1.0,           //in: scaling value (real part), defaults to 1
                         double scale_imag = 0.0,           //in: scaling value (imaginary part), defaults to 0
                         int dev_id = DEV_DEFAULT,          //in: device id (flat or kind-specific)
                         int dev_kind = DEV_DEFAULT,        //in: device kind (if present, <dev_id> is kind-specific)
                         talsh_task_t * talsh_task = NULL); ////inout: TAL-SH task (must be clean)
 int talshTensorContract_(const char * cptrn, talsh_tens_t * dtens, talsh_tens_t * ltens, talsh_tens_t * rtens, int copy_ctrl,
                          double scale_real, double scale_imag, int dev_id, int dev_kind, talsh_task_t * talsh_task);
// TAL-SH debugging:
//  1-norm of the tensor body image on Host:
 double talshTensorImageNorm1_cpu(const talsh_tens_t * talsh_tens);
#ifdef __cplusplus
}
#endif

//HEADER GUARD
#endif
