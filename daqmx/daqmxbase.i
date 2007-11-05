// $Id$
// SWIG (http://www.swig.org) definitions for
// National Instruments NI-DAQmx Base

// ruby-daqmxbase: A SWIG interface for Ruby and the NI-DAQmx Base data
// acquisition library.
// 
// Copyright (C) 2007 Ned Konz
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License.  You may obtain a copy
// of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//

// Will be Ruby module named Daqmxbase
%module  daqmxbase

%include "typemaps.i"
%include "exception.i"
%include "carrays.i"
%include "cdata.i"

%{
#include <string.h>
#include <stdlib.h>
#include "ruby.h"

// patch typo in v2.20f header file
#define  DAQmxReadBinaryI32  DAQmxBaseReadBinaryI32
#include "NIDAQmxBase.h"

static VALUE dmxError = Qnil;
static VALUE dmxWarning = Qnil;

int32 handle_DAQmx_error(int32 errCode)
{
  static const char errorSeparator[] = "ERROR : ";
  static const char warningSeparator[] = "WARNING : ";
  static const char *separator;
  size_t errorBufferSize;
  size_t prefixLength;
  char *errorBuffer;

  if (errCode == 0)
    return 0;

  separator = errCode < 0 ? errorSeparator : warningSeparator;
  errorBufferSize = (size_t)DAQmxBaseGetExtendedErrorInfo(NULL, 0);
  prefixLength = strlen(separator);
  errorBuffer = malloc(prefixLength + errorBufferSize);
  strcat(errorBuffer, separator);
  DAQmxBaseGetExtendedErrorInfo(errorBuffer + prefixLength, (uInt32)errorBufferSize);

  if (errCode < 0)
  {
    if (dmxError == Qnil)
      dmxError = rb_define_class("DAQmxBaseError", rb_eRuntimeError);
    rb_raise(dmxError, errorBuffer);
  }
  else if (errCode > 0)
  {
    if (dmxWarning == Qnil)
      dmxWarning = rb_define_class("DAQmxBaseWarning", rb_eRuntimeError);
    rb_raise(dmxWarning, errorBuffer);
  }

  return errCode;
}

%};

// patch typo in header file
#define  DAQmxReadBinaryI32  DAQmxBaseReadBinaryI32

%apply  unsigned long *OUTPUT { bool32 * };
%apply  unsigned long *OUTPUT { int32 * };
%apply  char *OUTPUT { char errorString[] };
%apply  float *OUTPUT { float64 *value };
%apply  unsigned long *OUTPUT { uInt32 *value };

%typemap(in) (float64 writeArray[]) {
  long len = 1;
  long i;
  float64 val;
  $1 = calloc(len, sizeof(float64));

  switch (rb_type($input))
  {
    case T_ARRAY:
      len = RARRAY($input)->len;
      $1 = realloc($1, sizeof(float64)*(size_t)len);
      for (i = 0; i < len; i++)
      {
        VALUE v;
        v = rb_ary_entry($input, i);
        switch (rb_type(v))
        {
          case T_FIXNUM:
            val = (float64)FIX2LONG(v);
            break;

          case T_FLOAT:
            val = (float64)RFLOAT(v)->value;
            break;

          default:
            goto Error;
        };
        $1[i] = val;
      }
      break;

    case T_FIXNUM:
      val = (float64)FIX2LONG($input);
      break;

    case T_FLOAT:
      val = (float64)RFLOAT($input)->value;
      break;

Error:
    default:
      free($1);
      $1 = NULL;
      rb_raise(rb_eTypeError, "writeArray must be FIXNUM, float, or array of float or fixnum");
      break;
  };
};

// free array allocated by above
%typemap(freearg) (float64 writeArray[]) {
  if ($1) free($1);
};

// ruby size param in: alloc array of given size
%typemap(in) (float64 readArray[], uInt32 arraySizeInSamps) {
  long len;

  if (FIXNUM_P($input))
    len = FIX2LONG($input);
  else
    rb_raise(rb_eTypeError, "readArray size must be FIXNUM");

  if (len <= 0)
    rb_raise(rb_eRangeError, "readArray size must be > 0 (but got %ld)", len);

  $1 = calloc((size_t)len, sizeof(float64));
  $2 = (uInt32)len;
};

// free array allocated by above
%typemap(freearg) (float64 readArray[], uInt32 arraySizeInSamps) {
  if ($1) free($1);
};

// make Ruby Array of FIXNUM
%typemap(argout) (float64 readArray[], uInt32 arraySizeInSamps) {
  long i;
  VALUE data;
  // result is return val from function
  if (result != 0)
  {
    $result = Qnil;
    free($1);
    handle_DAQmx_error(result);
  }

  // create Ruby array of given length
  data = rb_ary_new2($2);

  // populate it an element at a time.
  for (i = 0; i < (long)$2; i++)
    rb_ary_store(data, i, rb_float_new($1[i]));

  // $result is what will be passed to Ruby
  if (rb_type($result) != T_ARRAY)
  {
    if ($result != Qnil)
    {
      VALUE oldResult = $result;
      $result = rb_ary_new();
      rb_ary_push($result, oldResult);
    }
  }

  rb_ary_push($result, data);
};

// Note that TaskHandle is typedef'd as uInt32*
// so here &someTask is equivalent to a TaskHandle.
%inline{
  typedef struct { uInt32 t; } Task;
};

// pass string and size to C function
%typemap(in) (char *str, int len) {
  $1 = STR2CSTR($input);
  $2 = (int) RSTRING($input)->len;
};

// pass error code return from DAQmxBase functions to Ruby
%typemap(out) int32 {
  if ($1) handle_DAQmx_error($1);
  $result = LONG2FIX($1);
};

// ignore "bool32 *reserved" arguments
%typemap(in, numinputs=0) bool32 *reserved (bool32 temp) {
  temp = 0;
  $1 = &temp;
};

%extend Task {
  // if you give a non-empty name, you get LoadTask, else CreateTask.
  Task(const char taskName[]) {
    Task *t = (Task *)calloc(1, sizeof(Task));
    int32 result;
    if (&taskName[0] == NULL || taskName[0] == '\0')
      result = DAQmxBaseCreateTask(taskName, (TaskHandle *)(void *)&t);
    else
      result = DAQmxBaseLoadTask(taskName, (TaskHandle *)(void *)&t);
    if (result) handle_DAQmx_error(result);
    return t;
  }
  ~Task() {
    int32 result = DAQmxBaseStopTask((TaskHandle)(void *)$self);
    result = DAQmxBaseClearTask((TaskHandle)(void *)$self);
    free($self);
  }
};

%include "daqmxbase_decls.i"
%import "NIDAQmxBase.h"

//  vim: filetype=swig ts=2 sw=2 et ai
