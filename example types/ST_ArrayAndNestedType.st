TYPE ST_ArrayAndNestedType :
	STRUCT
    	TestString 		: STRING(55) := 'Test';   (* Test *)
		TestArray		: ARRAY[0..3] OF REAL;
		TestMultArray 	: ARRAY[0..1][2..3][4..5] OF INT;
		TestMultArray2	: ARRAY[0..1,2..3] OF DWORD;
		TestEnum		: ET_COLOR;
		TestStruct 		: ST_Analog;
	END_STRUCT
END_TYPE