macro( precompiled_header includes header_name build_pch)
    if (NOT "${CMAKE_GENERATOR}" STREQUAL "Xcode")
        message(STATUS "Precompiled header generation")
        # Get the compiler flags for this build type
        string( TOUPPER "CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}" flags_for_build_name )
        set( compile_flags "${CMAKE_CXX_FLAGS} ${${flags_for_build_name}}" )

        # Add all the Qt include directories
        foreach( item ${${includes}} )
            list( APPEND compile_flags "-I${item}" )
        endforeach()

        # Get the list of all build-independent preprocessor definitions
        get_directory_property( defines_global COMPILE_DEFINITIONS )
        list( APPEND defines ${defines_global} )

        # Get the list of all build-dependent preprocessor definitions
        string( TOUPPER "COMPILE_DEFINITIONS_${CMAKE_BUILD_TYPE}" defines_for_build_name )
        get_directory_property( defines_build ${defines_for_build_name} )
        list( APPEND defines ${defines_build} )

        # Add the "-D" prefix to all of them
        foreach( item ${defines} )
            list( APPEND all_define_flags "-D${item}" )
        endforeach()

        list( APPEND compile_flags ${all_define_flags} )

        # Prepare the compile flags var for passing to GCC
        separate_arguments( compile_flags )

        set (PCH_HEADER "${PROJECT_BINARY_DIR}/${header_name}.h")
        if (NOT MSVC)
            set (PCH_INCLUDE "-include ${PCH_HEADER}")
        else (NOT MSVC)
            set (PCH_INCLUDE "/FI${PCH_HEADER}")
            set (PCH_CPP "${PROJECT_BINARY_DIR}/${header_name}.cpp")
        endif (NOT MSVC)

        if( ${build_pch} )
            if(NOT MSVC)
               set (PCH ${PROJECT_BINARY_DIR}/${header_name}.h.gch)
               set (PCH_FORCE_USE "")
               add_custom_command(
                  OUTPUT ${PROJECT_BINARY_DIR}/${header_name}.h.gch
                  COMMAND ${CMAKE_CXX_COMPILER} -x c++-header -g  ${compile_flags} -o ${header_name}.h.gch ${header_name}.h
                  DEPENDS ${PROJECT_BINARY_DIR}/${header_name}.h
                  WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
                  VERBATIM
                  )
            else (NOT MSVC)
               # Create pre-compiled header file for MSVC.
               list (REMOVE_DUPLICATES compile_flags)
               set (PCH ${PROJECT_BINARY_DIR}/${header_name}.pch)
               # NOTE: MSVC is picky about PCH: it is difficult to share them amongst different projects (almost impossible).
               #       By default, if a PCH file was created by another project, it gets deleted before attempting compilation.
               #       Best solution would be to create PCH-files per project (per subdir).
               # set (PCH_FORCE_USE "/Fp${PCH} /Yu${PCH_HEADER}")
               set (PCH_FORCE_USE "")     # Temp -> do not use precompiled headers, not working right now!
               add_custom_command(
                  OUTPUT ${PROJECT_BINARY_DIR}/${header_name}.pch
                  COMMAND ${CMAKE_CXX_COMPILER} ${compile_flags} /c /Yc${header_name}.h /Fp${header_name}.pch ${header_name}.cpp
                  DEPENDS ${PROJECT_BINARY_DIR}/${header_name}.h ${PROJECT_BINARY_DIR}/${header_name}.cpp
                  WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
                  VERBATIM
                  )
            endif (NOT MSVC)
        else ( ${build_pch} )
            message(STATUS "No precompiled header")
            set (PCH_FORCE_USE "")
        endif( ${build_pch} )
    endif()
endmacro()

# Xcode PCH support. Has to be called *AFTER* the target is created.
# "header_name" - the name of the PCH header, without the extension; "all" or something similar;
#                  note that the source file compiling the header needs to have the same name
macro( xcode_pch target_name header_name )
    if( APPLE )
        set_target_properties(
            ${target_name}
            PROPERTIES
            XCODE_ATTRIBUTE_GCC_PREFIX_HEADER "${PROJECT_BINARY_DIR}/${header_name}.h"
            XCODE_ATTRIBUTE_GCC_PRECOMPILE_PREFIX_HEADER "YES"
        )
    endif()
endmacro()

# VStudio PCH support. Has to be called *AFTER* the target is created.
# "header_name" - the name of the PCH header, without the extension; "all" or something similar;
#                  note that *the source file compiling the header* needs to have the same name
macro( vstudio_pch target_name header_name )
    if( MSVC )
        target_sources(
            ${target_name}
            PUBLIC ${PCH_CPP}
            )  

         ### TODO: work on this! If this is included in each CMakeLists.txt subdir, it should do the trick...
        set_source_file_properties(
            ${PCH_CPP}
            PROPERTIES
               COMPILE_FLAGS "${PCH_INCLUDE} ${PCH_FORCE_USE} /Yc"
        ) 
    endif( MSVC )
endmacro()