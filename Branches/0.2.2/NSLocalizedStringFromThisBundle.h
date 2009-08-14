#define NSLocalizedStringFromThisBundle(key, comment) \
	    [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]
