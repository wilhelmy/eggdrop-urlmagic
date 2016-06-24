// Copyright 2013 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Author: jdtang@google.com (Jonathan Tang)
// Author (TCL): Moritz Wilhelmy, mw at barfooze dot de
//
// Retrieves the title of a page.
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <tcl.h>
#include <gumbo.h>

#ifndef CONST84
#	define CONST84
#endif

Tcl_CmdProc Tcl_htmltitle;

int Htmltitle_Init(Tcl_Interp *interp)
{
	Tcl_PkgProvide(interp, "Htmltitle", "1");
	Tcl_CreateCommand(interp, "htmltitle", Tcl_htmltitle, NULL, NULL);

	if (Tcl_InitStubs(interp, "8.1", 0) == NULL) {
		return TCL_ERROR;
	}

	return TCL_OK;
}

int Htmltitle_Unload(Tcl_Interp *interp, int flags)
{
	return TCL_OK;
}

static const char* find_title(const GumboNode* root)
{
  if(root->type != GUMBO_NODE_ELEMENT) return NULL;

  const GumboVector* root_children = &root->v.element.children;
  for (int i = 0; i < root_children->length; ++i) {
    GumboNode* child = (GumboNode*)root_children->data[i];
    if (child->type == GUMBO_NODE_ELEMENT) 
    {
      if (child->v.element.tag == GUMBO_TAG_TITLE)
      {
        if (child->v.element.children.length != 1) 
        {
          return "";
        }
        GumboNode* title_text = (GumboNode*)child->v.element.children.data[0];
        if(title_text->type != GUMBO_NODE_TEXT)
          return NULL;
        return title_text->v.text.text;
      }
      const char * title = find_title( child );
      if (title) return title;
    }
  }
  return NULL;
}

int Tcl_htmltitle(ClientData dummy, Tcl_Interp *interp, int argc, CONST84 char *argv[])
{
	char const error[] = "Wrong # args: usage is \"htmltitle str\"";
	char const notfound[] = "";

	if (argc != 2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(error, -1));
		return TCL_ERROR;
	}

  char * str = (char*)argv[1];
  /*
  if ((unsigned char)str[0] == 0xEF
    && (unsigned char)str[1] == 0xBB
    && (unsigned char)str[2] == 0xBF) // skip bom or else gumbo fails
    str += 3;
  */
  
	size_t input_length = strlen(str);
	GumboOutput* output = gumbo_parse_with_options(
			&kGumboDefaultOptions, str, input_length);
	const char* title = find_title(output->root);

  if (title)
  	Tcl_SetObjResult(interp, Tcl_NewStringObj(title, -1));
  else
    Tcl_SetObjResult(interp, Tcl_NewStringObj(notfound, -1));

	gumbo_destroy_output(&kGumboDefaultOptions, output);

	return TCL_OK;
}

