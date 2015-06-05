# Copyright (c) 2013  Peter Zotov <whitequark@whitequark.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

import sublime_plugin
import sublime
import subprocess
import re
from shutil import which

OCPKEY = "OCaml Autocompletion"
DEBUG = True

class SublimeOCPIndex():
    local_cache = dict()

    def run_ocp(self, command, includes, module, query, context, moreArgs, settings):
        bin_path = which('ocp-index')
        if bin_path is None:
            opam_process = subprocess.Popen('opam config var bin', stdout=subprocess.PIPE, shell=True)
            bin_path = opam_process.stdout.read().decode('utf-8').rstrip() + '/ocp-index'

        args = [bin_path, command]

        if context is not None:
            args.append('--context=' + context)

        for include in includes:
            args.append('-I')
            args.append(include)

        buildDir = settings.get('sublime_ocp_index_build_dir')
        if buildDir is not None:
            args.append('--build=' + buildDir)

        if module is not None:
            args.append('-F')
            args.append(module)

        args += moreArgs
        args.append(query)

        if (DEBUG):
            print("'" + ' '.join(args) + "'")

        # Assumes the first folder is the build directory. Usually a safe assumption.
        cwd = None if len(includes) < 1 else includes[0]

        proc = subprocess.Popen(args,
                    cwd=cwd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE)

        (stdoutdata, stderrdata) = proc.communicate()

        error  = stderrdata.decode('utf-8').strip()
        output = stdoutdata.decode('utf-8').strip()

        if error:
            if (DEBUG):
                print(error)
            return (False, error)
        else:
            if (DEBUG):
                print(output)
            return (True, output)

    def extract_query(self, view, location):
        line = view.substr(sublime.Region(view.line(location).begin(), location))
        match = re.search(r"[,\s]*([A-Z][\w_.#']*|[\w_#']+)$", line)

        if match != None:
            (queryString,) = match.groups()

            header = view.substr(sublime.Region(0, 4096))
            module = None
            context = None

            if view.file_name() != None:
                (moduleName,) = re.search(r"(\w+)\.ml.*$", view.file_name()).groups()
                module = moduleName[0].upper() + moduleName[1:]

                (line,col) = view.rowcol(location)
                context = "%s:%d,%d" % (view.file_name(), line, col)


            settings = view.settings()

            return (module, queryString, context, settings)
        else:
            return None

    def query_type(self, view, region):
        endword = view.word(region).end()
        while view.substr(endword) in ['_', '#', '\'']:
            endword = endword + 1
            if view.substr(endword) is not ' ':
                endword = view.word(endword).end()

        query = self.extract_query(view, endword)

        if query is not None:
            (module, queryString, context, settings) = query

            (success, result) = self.run_ocp('type', view.window().folders(), module, queryString, context, [], settings)

            if (result is None or len(result) == 0):
                return "Unknown type: '%s'" % queryString
            else:
                return "Type: %s" % result


    def query_completions(self, view, prefix, location):
        query = self.extract_query(view, location)

        if query is not None:
            (module, queryString, context, settings) = query

            if view.file_name().endswith('.mli'):
                (show, hide) = ('t,m,s,k', 'v,e,c')
            else:
                (show, hide) = ('v,e,c,m,k', 't,s,k')

            (success, output) = self.run_ocp('complete',
                        view.window().folders(), module, queryString, context,
                        ['--format', '%q %p %k %t', '--show', show, '--hide', hide], settings)

            if (success is False):
                results = [(output,"")]
            else:
                results = []

                if prefix == "_":
                    results.append(('_\t wildcard', '_'))
                if prefix == "in":
                    results.append(('in\tkeyword', 'in'))

                variants = re.sub(r"\n\s+", " ", output).split("\n")
                if (DEBUG):
                    print(variants)

                def make_result(actual_replacement, replacement, rest):
                    return replacement + "\t" + rest.strip(), actual_replacement

                for variant in variants:
                    if variant.count(" ") > 1:
                        (actual_replacement, replacement, rest) = variant.split(" ", 2)
                        if rest.startswith("module sig"):
                            rest = "module sig .. end"
                        offset = actual_replacement.find(prefix)
                        if offset > 0:
                            actual_replacement = actual_replacement[offset:]
                        results.append(make_result(actual_replacement, replacement, rest))

                if view.buffer_id() in self.local_cache:
                    for local in self.local_cache[view.buffer_id()]:
                        results.append(make_result(local, local, "let"))

            return results, sublime.INHIBIT_WORD_COMPLETIONS | sublime.INHIBIT_EXPLICIT_COMPLETIONS

    def extract_locals(self, view):
        region = view.sel()[0]
        scopes = set(view.scope_name(region.begin()).split(" "))
        if len(set(["source.ocaml", "source.ocamllex", "source.ocamlyacc"]) & scopes) == 0:
            return

        local_defs = []
        view.find_all(r"let(\s+rec)?\s+(([?~]?[\w']+\s*)+)=", 0, r"\2", local_defs)
        view.find_all(r"fun\s+(([?~]?[\w']+\s*)+)->", 0, r"\1", local_defs)

        locals = set()
        for definition in local_defs:
            for local in definition.split():
                (local,) = re.match(r"^[?~]?(.+)", local).groups()
                locals.add(local)

        self.local_cache[view.buffer_id()] = list(locals)



## Boilerplate and connecting plugin classes to the real logic
sublimeocp = SublimeOCPIndex()

class SublimeOCPEventListener(sublime_plugin.EventListener):

    def on_query_completions(self, view, prefix, locations):
        if len(locations) != 1:
            return

        location = locations[0]
        scopes = set(view.scope_name(location).split(" "))

        if len(set(["source.ocaml", "source.ocamllex", "source.ocamlyacc"]) & scopes) == 0:
            return None

        return sublimeocp.query_completions(view, prefix, locations[0])

    if int(sublime.version()) < 3014:
        def on_close(self, view):
            if view.buffer_id() in sublimeocp.local_cache:
                sublimeocp.local_cache.pop(view.buffer_id())

        def on_load(self, view):
            sublimeocp.extract_locals(view)

        def on_post_save(self, view):
            sublimeocp.extract_locals(view)

        def on_selection_modified(self, view):
            view.erase_status(OCPKEY)

    else:
        def on_close_async(self, view):
            sublimeocp.local_cache.pop(view.buffer_id())

        def on_load_async(self, view):
            sublimeocp.extract_locals(view)

        def on_post_save_async(self, view):
            sublimeocp.extract_locals(view)

        def on_selection_modified_async(self, view):
            view.erase_status(OCPKEY)

class SublimeOcpTypes(sublime_plugin.TextCommand):
        def run(self, enable):
            view = self.view

            region = view.sel()[0]
            scopes = set(view.scope_name(region.begin()).split(" "))

            if len(set(["source.ocaml", "source.ocamllex", "source.ocamlyacc"]) & scopes) > 0:
                result = sublimeocp.query_type(view, region)

                if result is not None:
                    view.set_status(OCPKEY, result)
