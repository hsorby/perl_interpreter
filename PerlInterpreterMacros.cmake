
MACRO( IS_PERL_VARIABLE_DEFINED VAR LOCAL_PERL_EXECUTABLE )
	SET( STR_CONFIG "Config" )
	SET( VARIABLE_DEFINED FALSE )
	EXECUTE_PROCESS( COMMAND ${LOCAL_PERL_EXECUTABLE} -MConfig -e print -e "$${STR_CONFIG}{\"use${VAR}\"}"
	 OUTPUT_VARIABLE PERL_OUTPUT_VARIABLE
		 ERROR_VARIABLE PERL_ERROR_VARIABLE
		 RESULT_VARIABLE PERL_RETURN_VARIABLE )
	IF( NOT PERL_RETURN_VALUE AND PERL_OUTPUT_VARIABLE )
		SET( VARIABLE_DEFINED TRUE )
	ENDIF( NOT PERL_RETURN_VALUE AND PERL_OUTPUT_VARIABLE )

	SET( PERL_OUTPUT_VARIABLE )
	SET( PERL_ERROR_VARIABLE )
	SET( PERL_RETURN_VARIABLE )
	SET( STR_CONFIG )
ENDMACRO( )

MACRO( DEFINE_PERL_C_FLAGS LOCAL_PERL_EXECUTABLE )
	EXECUTE_PROCESS(COMMAND ${LOCAL_PERL_EXECUTABLE} -MExtUtils::Embed -e ccopts -e ldopts
		OUTPUT_VARIABLE PERL_OUTPUT_VARIABLE
		ERROR_VARIABLE PERL_ERROR_VARIABLE
		RESULT_VARIABLE PERL_RETURN_VARIABLE )
	IF( NOT PERL_RETURN_VARIABLE )
		FILE( TO_CMAKE_PATH "${PERL_OUTPUT_VARIABLE}" PERL_C_FLAGS )
		#SET( PERL_C_FLAGS ${PERL_OUTPUT_VARIABLE} )
	ELSE( NOT PERL_RETURN_VARIABLE )
		MESSAGE( ERROR "Problem with perl: ${PERL_ERROR_VARIABLE}" )
	ENDIF( NOT PERL_RETURN_VARIABLE )

	SET( PERL_OUTPUT_VARIABLE )
	SET( PERL_ERROR_VARIABLE )
	SET( PERL_RETURN_VARIABLE )
ENDMACRO( )

MACRO( DEFINE_PERL_API_STRING LOCAL_PERL_EXECUTABLE )
	# Have to set this string because cmake will interfere with
	# $Config
	SET( STR_CONFIG "Config" )
	EXECUTE_PROCESS(COMMAND ${LOCAL_PERL_EXECUTABLE} -MConfig -e print -e "$${STR_CONFIG}{api_versionstring}"
	 OUTPUT_VARIABLE PERL_OUTPUT_VARIABLE
		 ERROR_VARIABLE PERL_ERROR_VARIABLE
		 RESULT_VARIABLE PERL_RETURN_VARIABLE )
	IF( NOT PERL_RETURN_VARIABLE )
		SET( PERL_API_STRING ${PERL_OUTPUT_VARIABLE} )
		SET( PERL_VARIABLES threads multiplicity 64bitall longdouble perlio )
		FOREACH( VARIABLE ${PERL_VARIABLES} )
			IS_PERL_VARIABLE_DEFINED( ${VARIABLE} ${LOCAL_PERL_EXECUTABLE} )
			IF( VARIABLE_DEFINED )
				SET( PERL_API_STRING ${PERL_API_STRING}-${VARIABLE} )
			ENDIF( VARIABLE_DEFINED )
		ENDFOREACH( VARIABLE ${PERL_VARIABLES} )

		SET( VARIABLE_DEFINED )
	ELSE( NOT PERL_RETURN_VARIABLE )
		MESSAGE( ERROR "Problem with perl: ${PERL_ERROR_VARIABLE}" )
	ENDIF( NOT PERL_RETURN_VARIABLE )

	SET( PERL_OUTPUT_VARIABLE )
	SET( PERL_ERROR_VARIABLE )
	SET( PERL_RETURN_VARIABLE )
	SET( STR_CONFIG )
ENDMACRO( )

MACRO( PERL_ADJUST_DARWIN_LIB_VARIABLE varname LOCAL_PERL_EXECUTABLE )
	STRING( TOUPPER PERL_${varname} FINDPERL_VARNAME )
	STRING( TOLOWER install${varname} PERL_VARNAME )
	IF(NOT PERL_MINUSV_OUTPUT_VARIABLE)
		EXECUTE_PROCESS(
			COMMAND
			${LOCAL_PERL_EXECUTABLE} -V
			OUTPUT_VARIABLE
			PERL_MINUSV_OUTPUT_VARIABLE
			RESULT_VARIABLE
			PERL_MINUSV_RESULT_VARIABLE
			)
	ENDIF()

	IF(NOT PERL_MINUSV_RESULT_VARIABLE)
		STRING(REGEX MATCH "(${PERL_VARNAME}.*points? to the Updates directory)"
			PERL_NEEDS_ADJUSTMENT ${PERL_MINUSV_OUTPUT_VARIABLE})

		IF(PERL_NEEDS_ADJUSTMENT)
			STRING(REGEX REPLACE "(.*)/Updates/" "/System/\\1/" ${FINDPERL_VARNAME} ${${FINDPERL_VARNAME}})
		ENDIF(PERL_NEEDS_ADJUSTMENT)

	ENDIF(NOT PERL_MINUSV_RESULT_VARIABLE)
ENDMACRO()

MACRO( DEFINE_PERL_ARCHLIB_DIR LOCAL_PERL_EXECUTABLE )
	EXECUTE_PROCESS(
		COMMAND ${LOCAL_PERL_EXECUTABLE} -V:archlib
		OUTPUT_VARIABLE PERL_ARCHLIB_OUTPUT_VARIABLE
		RESULT_VARIABLE PERL_ARCHLIB_RESULT_VARIABLE
	)
	IF( NOT PERL_ARCHLIB_RESULT_VARIABLE )
		STRING(REGEX REPLACE "archlib='([^']+)'.*" "\\1" PERL_ARCHLIB ${PERL_ARCHLIB_OUTPUT_VARIABLE})
		PERL_ADJUST_DARWIN_LIB_VARIABLE( ARCHLIB ${LOCAL_PERL_EXECUTABLE} )
		FILE( TO_CMAKE_PATH ${PERL_ARCHLIB} PERL_ARCHLIB_DIR )
	ENDIF( NOT PERL_ARCHLIB_RESULT_VARIABLE )
ENDMACRO()

MACRO( FIND_PERL_LIBRARY LOCAL_PERL_EXECUTABLE NO_DEFAULT_PATH )

	IF( NO_DEFAULT_PATH )
		SET( LOCAL_NO_DEFAULT_PATH NO_DEFAULT_PATH )
	ENDIF()

	### PERL_VERSION
	EXECUTE_PROCESS(
		COMMAND
			${LOCAL_PERL_EXECUTABLE} -V:version
		OUTPUT_VARIABLE
			PERL_VERSION_OUTPUT_VARIABLE
		RESULT_VARIABLE
			PERL_VERSION_RESULT_VARIABLE
	)
	IF(NOT PERL_VERSION_RESULT_VARIABLE)
	STRING(REGEX REPLACE "version='([^']+)'.*" "\\1" PERL_VERSION ${PERL_VERSION_OUTPUT_VARIABLE})
	ENDIF(NOT PERL_VERSION_RESULT_VARIABLE)

	### PERL_ARCHNAME
	EXECUTE_PROCESS(
		COMMAND
			${LOCAL_PERL_EXECUTABLE} -V:archname
		OUTPUT_VARIABLE
			PERL_ARCHNAME_OUTPUT_VARIABLE
		RESULT_VARIABLE
			PERL_ARCHNAME_RESULT_VARIABLE
	)
	IF(NOT PERL_ARCHNAME_RESULT_VARIABLE)
		STRING(REGEX REPLACE "archname='([^']+)'.*" "\\1" PERL_ARCHNAME ${PERL_ARCHNAME_OUTPUT_VARIABLE})
	ENDIF(NOT PERL_ARCHNAME_RESULT_VARIABLE)

	### PERL_POSSIBLE_LIB_PATHS
	SET( PERL_POSSIBLE_LIB_PATHS )
	SET(PERL_POSSIBLE_LIB_PATHS
		${PERL_ARCHLIB}/CORE
		${PERL_VERSION}/${PERL_ARCHNAME}/CORE
		${PERL_VERSION}/CORE
	)

	### PERL_POSSIBLE_LIBRARY_NAME
	SET( PERL_POSSIBLE_LIBRARY_NAME )
	EXECUTE_PROCESS(
		COMMAND
			${LOCAL_PERL_EXECUTABLE} -V:libperl
		OUTPUT_VARIABLE
			PERL_LIBRARY_OUTPUT_VARIABLE
		RESULT_VARIABLE
			PERL_LIBRARY_RESULT_VARIABLE
	)

	IF(NOT PERL_LIBRARY_RESULT_VARIABLE)
		STRING(REGEX REPLACE ".*libperl='([^']+)'.*" "\\1" PERL_LIBRARY_OUTPUT_VARIABLE ${PERL_LIBRARY_OUTPUT_VARIABLE})
		FOREACH(_perl_lib_path ${PERL_POSSIBLE_LIB_PATHS})
			FILE( TO_CMAKE_PATH "${_perl_lib_path}/${PERL_LIBRARY_OUTPUT_VARIABLE}" TEMP_LIBRARY_NAME )
			SET( PERL_POSSIBLE_LIBRARY_NAME ${PERL_POSSIBLE_LIBRARY_NAME} ${TEMP_LIBRARY_NAME} )
		ENDFOREACH(_perl_lib_path ${PERL_POSSIBLE_LIB_PATHS})
	ENDIF(NOT PERL_LIBRARY_RESULT_VARIABLE)

	### PERL_LIBRARY
	SET(CMAKE_FIND_LIBRARY_SUFFIXES_OLD ${CMAKE_FIND_LIBRARY_SUFFIXES})
	SET(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_STATIC_LIBRARY_SUFFIX})
	UNSET(PERL_STATIC_LIBRARY CACHE)
	FIND_LIBRARY(PERL_STATIC_LIBRARY
		NAMES perl
		PATHS ${PERL_POSSIBLE_LIB_PATHS} ${LOCAL_NO_DEFAULT_PATH})
	IF(PERL_STATIC_LIBRARY)
		# Check for crypt library
		# find static cyrpt lib
		UNSET(CRYPT_STATIC_LIBRARY CACHE)
		FIND_LIBRARY(CRYPT_STATIC_LIBRARY
			NAMES crypt
			PATHS ${PERL_POSSIBLE_LIB_PATHS})
		MARK_AS_ADVANCED(CRYPT_STATIC_LIBRARY)
	ENDIF(PERL_STATIC_LIBRARY)
	SET(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES_OLD})

	UNSET(PERL_LIBRARY CACHE)
	FIND_LIBRARY(PERL_LIBRARY
		NAMES
			${PERL_LIBRARY_OUTPUT_VARIABLE}
			${PERL_POSSIBLE_LIBRARY_NAME}
			perl${PERL_VERSION}
			perl
		PATHS
			${PERL_POSSIBLE_LIB_PATHS}
		${LOCAL_NO_DEFAULT_PATH}
	)

ENDMACRO()

MACRO( DEFINE_PERL_EXTRA_C_FLAGS LOCAL_PERL_EXECUTABLE)
	### PERL_EXTRA_C_FLAGS
	EXECUTE_PROCESS(
		COMMAND
			${LOCAL_PERL_EXECUTABLE} -V:cppflags
		OUTPUT_VARIABLE
			PERL_CPPFLAGS_OUTPUT_VARIABLE
		RESULT_VARIABLE
			PERL_CPPFLAGS_RESULT_VARIABLE
		)
	IF(NOT PERL_CPPFLAGS_RESULT_VARIABLE)
		STRING(REGEX REPLACE "cppflags='([^']+)'.*" "\\1" PERL_EXTRA_C_FLAGS ${PERL_CPPFLAGS_OUTPUT_VARIABLE})
	ENDIF(NOT PERL_CPPFLAGS_RESULT_VARIABLE)

ENDMACRO()

MACRO( SEPARATE_PERL_C_FLAGS C_FLAGS )
	# Strip out all include directory information and set into PERL_INCLUDE_DIRS
	IF( DEFINED WIN32 )
		STRING( REGEX MATCHALL "[ \t\r\n]-I\"[^\"]+\"" TMP_INCLUDE_DIRS ${C_FLAGS} )
	ELSE( DEFINED WIN32 )
		STRING( REGEX MATCHALL "[ \t\r\n]-I[^ \t\r\n]+" TMP_INCLUDE_DIRS ${C_FLAGS} )
	ENDIF( DEFINED WIN32 )

	SET( PERL_INCLUDE_DIRS )
	FOREACH( DIR ${TMP_INCLUDE_DIRS} )
		IF ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n]-I\"([^\"]+)\"" TMP_INCLUDE_DIR ${DIR} )
		ELSE ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n]-I([^ \t\r\n]+)" TMP_INCLUDE_DIR ${DIR} )
		ENDIF ( DEFINED WIN32 )
		SET( PERL_INCLUDE_DIRS ${PERL_INCLUDE_DIRS} ${CMAKE_MATCH_1} )
	ENDFOREACH( DIR ${TMP_INCLUDE_DIRS} )

	# Strip out all link information and set into PERL_LINK_LIBRARY_DIRS
	IF ( DEFINED WIN32 )
		STRING( REGEX MATCHALL "[ \t\r\n]-libpath:[^ \t\r\n]+" TMP_LINK_LIBRARY_DIRS ${C_FLAGS} )
	ELSE ( DEFINED WIN32 )
		STRING( REGEX MATCHALL "[ \t\r\n]-L[^ \t\r\n]+" TMP_LINK_LIBRARY_DIRS ${C_FLAGS} )
	ENDIF ( DEFINED WIN32 )

	SET( PERL_LINK_LIBRARY_DIRS )
	FOREACH( DIR ${TMP_LINK_LIBRARY_DIRS} )
		IF ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n]-libpath:([^ \t\r\n]+)" TMP_LIBRARY_DIR ${DIR} )
		ELSE ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n]-L([^ \t\r\n]+)" TMP_LIBRARY_DIR ${DIR} )
		ENDIF ( DEFINED WIN32 )
		SET( PERL_LINK_LIBRARY_DIRS ${PERL_LINK_LIBRARY_DIRS} ${CMAKE_MATCH_1} )
	ENDFOREACH( DIR ${TMP_LINK_LIBRARY_DIRS} )

	# Strip out all link information and set into PERL_LINK_LIBRARIES
	IF ( DEFINED WIN32 )
		STRING( REGEX MATCHALL "[ \t\r\n]([^ \t\r\n]+[.]lib|\"[^\"]+[.]lib\")" TMP_LINK_LIBRARIES ${C_FLAGS} )
	ELSE ( DEFINED WIN32 )
		STRING( REGEX MATCHALL "[ \t\r\n]-l[^ \t\r\n]+" TMP_LINK_LIBRARIES ${C_FLAGS} )
	ENDIF ( DEFINED WIN32 )

	SET( PERL_LINK_LIBRARIES )
	FOREACH( LIB ${TMP_LINK_LIBRARIES} )
		IF ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n]\"([^\"]+[.]lib)\"" TMP_LIBRARY ${LIB} )
			IF ( NOT CMAKE_MATCH_1 )
				STRING( REGEX MATCH "[ \t\r\n]([^ \t\r\n]+[.]lib)" TMP_LIBRARY ${LIB} )
			ENDIF ( NOT CMAKE_MATCH_1 )
		ELSE ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n]-l([^ \t\r\n]+)" TMP_LIBRARY ${LIB} )
		ENDIF ( DEFINED WIN32 )
		SET( PERL_LINK_LIBRARIES ${PERL_LINK_LIBRARIES} ${CMAKE_MATCH_1} )
	ENDFOREACH( LIB ${TMP_LINK_LIBRARIES} )

	# Strip out all c flags and set into PERL_COMPILER_FLAGS, just looking at the defines for now
	IF( DEFINED WIN32 )
		STRING( REGEX MATCHALL "[ \t\r\n]-[D][^ \t\r\n]+" TMP_COMPILER_FLAGS ${C_FLAGS} )
	ENDIF( DEFINED WIN32 )

	SET( PERL_COMPILER_FLAGS )
	FOREACH( FLAG ${TMP_COMPILER_FLAGS} )
		IF ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n](-[D][^ \t\r\n]+)" TMP_FLAG ${FLAG} )
		ELSE ( DEFINED WIN32 )
			STRING( REGEX MATCH "[ \t\r\n](-D[^ \t\r\n]+)" TMP_FLAG ${FLAG} )
		ENDIF ( DEFINED WIN32 )
		SET( PERL_COMPILER_FLAGS ${PERL_COMPILER_FLAGS} ${CMAKE_MATCH_1} )
	ENDFOREACH( FLAG ${TMP_COMPILER_FLAGS} )

	SET( TMP_INCLUDE_DIRS )
	SET( TMP_INCLUDE_DIR )
	SET( TMP_LINK_LIBRARY_DIR )
	SET( TMP_LIBRARY_DIR )
	SET( TMP_LINK_LIBRARIES )
	SET( TMP_LIBRARY )
	SET( TMP_COMPILER_FLAGS )
	SET( TMP_FLAG )
ENDMACRO( SEPARATE_PERL_C_FLAGS )

