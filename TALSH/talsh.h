/** ExaTensor::TAL-SH: Device-unified user-level API header.
REVISION: 2016/02/12

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

//PARAMETERS:
#define TALSH_MAX_ACTIVE_TASKS 4096 //max number of active tasks on all devices on a node

//ERROR CODES:
#define TALSH_SUCCESS 0
#define TALSH_FAILURE -666
#define TALSH_NOT_INITIALIZED 1
#define TALSH_ALREADY_INITIALIZED 2
#define TALSH_INVALID_ARGS 3

//Exported functions:
#ifdef __cplusplus
extern "C"{
#endif
// TAL-SH control:
//  Initialize TAL-SH:
 int talshInit(size_t * host_buf_size, int * host_arg_max, int ngpus, int gpu_list[],
                                                           int nmics, int mic_list[],
                                                           int namds, int amd_list[]);
//  Shutdown TAL-SH:
 int talshShutdown();
//  Get the flat device Id:
 int talshFlatDevId(int dev_kind, int dev_num);
//  Get the kind-specific device Id:
 int talshKindDevId(int dev_id, int * dev_kind);

#ifdef __cplusplus
}
#endif

//HEADER GUARD
#endif
