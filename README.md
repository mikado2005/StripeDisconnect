# StripeDisconnect

This app demonstrates an apparent bug in StripeTerminal v2.20.2 involving the method Terminal.shared.disconnectReader.
When run on real iOS hardware with a live Stripe Bluetooth reader in proximity, this app will discover the reader, connect to the reader, disconnect from the reader, and then discover it again, in a loop. [Note that any errors in interacting with the reader will halt the app.]

When run using the StripeTerminal reader simulator, the method Terminal.shared.disconnectReader completes without error, but the Terminal object is still connected to the reader.  Hence, the following call to method Terminal.shared.discoverReaders fails with the error message:

Error Domain=com.stripe-terminal Code=1110 "Already connected to a reader. Disconnect from the reader, or power it off before trying again." UserInfo={NSLocalizedDescription=Already connected to a reader. Disconnect from the reader, or power it off before trying again., com.stripe-terminal:Message=Already connected to a reader. Disconnect from the reader, or power it off before trying again.}

Please read comments in the ViewController.swift file for instructions on usage.

