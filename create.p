/*
	ATM performance test:
	create the tables in the empty database
	
	21-Sep-95	ghb
	
	Copyright (c) 1995, Progress Software Corporation
*/	
    run prodict/load_df.p ("account.df").
    run prodict/load_df.p ("branch.df").
    run prodict/load_df.p ("teller.df").
    run prodict/load_df.p ("history1.df").
    run prodict/load_df.p ("history2.df").
    run prodict/load_df.p ("history3.df").
    run prodict/load_df.p ("history4.df").
    run prodict/load_df.p ("config.df").
    run prodict/load_df.p ("client.df").
    run prodict/load_df.p ("results.df").
