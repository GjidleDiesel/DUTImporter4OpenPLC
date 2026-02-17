TYPE ST_ArrayAndNestedTypeDebug :
	STRUCT
    	TestString 		: STRING(55) := 'Test';   (* Test *)
		TestArray		: ARRAY[0..3] OF REAL;
		TestMultArray 	: ARRAY[0..1][2..3][4..5] OF INT;
		TestStruct 		: ST_Analog;
		TestEnum		: ET_COLOR;
	END_STRUCT
END_TYPE