/*
	ATM performance test:
	create the tables in the empty database
	
	21-Sep-95	ghb
	
	Copyright (c) 1995, Progress Software Corporation
*/	
    run prodict/load_df.p ("schema/account.df").
    run prodict/load_df.p ("schema/branch.df").
    run prodict/load_df.p ("schema/teller.df").
    run prodict/load_df.p ("schema/history1.df").
    run prodict/load_df.p ("schema/history2.df").
    run prodict/load_df.p ("schema/history3.df").
    run prodict/load_df.p ("schema/history4.df").
    run prodict/load_df.p ("schema/config.df").
    run prodict/load_df.p ("schema/client.df").
    run prodict/load_df.p ("schema/results.df").
