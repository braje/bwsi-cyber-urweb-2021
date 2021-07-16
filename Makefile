.PHONY: blog-run counter-run urweb-bcrypt/bcrypt.a

urweb-bcrypt/bcrypt.a:
	$(MAKE) -C urweb-bcrypt/

# Build the counter executable
counter.exe: counter.ur counter.urs counter.urp
	urweb counter

# Run the counter application.  The application can be found by
# browsing to http://localhost:8080/Counter/main
counter-run: counter.exe
	./counter.exe

# Build the blog executable and build its database definition
blog.exe: blog.ur blog.urs blog.urp urweb-bcrypt/bcrypt.a
	\rm -f myblog.db
	urweb -db myblog.db -dbms sqlite blog

# Load the database schema into a blank database, and then
# add the test data
myblog.db: blog-test-data.sql blog.exe
	sqlite3 myblog.db < myblog.sql
	sqlite3 myblog.db < blog-test-data.sql

# Serve up the blog application.  Point your browser at
# http://localhost:8080/blog to see it in action!
blog-run: myblog.db
	./blog.exe
