/** ExaTensor::TAL-SH: Memory management API header.
REVISION: 2016/02/08
Copyright (C) 2015 Dmitry I. Lyakh (email: quant4me@gmail.com)
Copyright (C) 2015 Oak Ridge National Laboratory (UT-Battelle)

This source file is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
-------------------------------------------------------------------------------
**/

#ifndef _MEM_MANAGER_H
#define _MEM_MANAGER_H

//Types:
// Generic slab:
typedef struct{
 size_t max_entries;    //max number of entries in the slab
 size_t entry_size;     //entry size in bytes (can be larger than the slab data type because of alignment)
 size_t alignment;      //optional alignment of entries with respect to the slab base
 size_t first_free;     //first free entry number (stack pointer)
 void * slab_base;      //slab base pointer
 void ** free_entries;  //stack of free entries
} slab_t;

//Exported functions:
#ifdef __cplusplus
extern "C"{
#endif
//Buffer memory management (all devices):
 int arg_buf_allocate(size_t *arg_buf_size, int *arg_max, int gpu_beg, int gpu_end); //generic
 int arg_buf_deallocate(int gpu_beg, int gpu_end); //generic
 int arg_buf_clean_host(); //Host only
 int arg_buf_clean_gpu(int gpu_num); //NVidia GPU only
 int get_blck_buf_sizes_host(size_t *blck_sizes); //Host only
 int get_blck_buf_sizes_gpu(int gpu_num, size_t *blck_sizes); //NVidia GPU only
 int get_buf_entry_host(size_t bsize, char **entry_ptr, int *entry_num); //Host only
 int free_buf_entry_host(int entry_num); //Host only
 int get_buf_entry_gpu(int gpu_num, size_t bsize, char **entry_ptr, int *entry_num); //NVidia GPU only
 int free_buf_entry_gpu(int gpu_num, int entry_num); //NVidia GPU only
 int const_args_entry_get(int gpu_num, int *entry_num); //NVidia GPU only
 int const_args_entry_free(int gpu_num, int entry_num); //NVidia GPU only
 int mem_free_left(int dev_id, size_t * free_mem); //generic
 int mem_print_stats(int dev_id); //generic
 int slab_create(slab_t ** slab);
 int slab_construct(slab_t * slab, size_t slab_entry_size, size_t slab_max_entries, size_t align);
 int slab_entry_get(slab_t * slab, void ** slab_entry);
 int slab_entry_release(slab_t * slab, void * slab_entry);
 int slab_destruct(slab_t * slab);
 int slab_destroy(slab_t * slab);
 int host_mem_alloc_pin(void **host_ptr, size_t tsize); //generic
 int host_mem_free_pin(void *host_ptr); //generic
 int host_mem_register(void *host_ptr, size_t tsize); //generic
 int host_mem_unregister(void *host_ptr); //generic
 int mi_entry_get(int ** mi_entry_p); //generic
 int mi_entry_release(int * mi_entry_p); //generic
 int mi_entry_pinned(int * mi_entry_p); //generic
#ifndef NO_GPU
 int gpu_mem_alloc(void **dev_ptr, size_t tsize, int gpu_id = -1); //NVidia GPU only
 int gpu_mem_free(void *dev_ptr, int gpu_id = -1); //NVidia GPU only
#endif
#ifdef __cplusplus
}
#endif

#endif
