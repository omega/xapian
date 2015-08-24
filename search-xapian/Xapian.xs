// Disable any deprecation warnings for Xapian methods/functions/classes.
#define XAPIAN_DEPRECATED(D) D
#include <xapian.h>
#include <string>
#include <vector>

// Stop Perl headers from even thinking of doing '#define bool char' or
// '#define bool int', which they would do with compilers other than GCC.
#define HAS_BOOL

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif
#undef get_context

using namespace std;
using namespace Xapian;

extern void handle_exception(void);

/* PerlStopper class
 *
 * Make operator() call Perl $OBJECT->stop_word
 */

class PerlStopper : public Stopper {
    public:
	PerlStopper(SV * obj) { SV_stopper_ref = newRV_inc(obj); }
	~PerlStopper() { sv_2mortal(SV_stopper_ref); }
	bool operator()(const string &term) const {
	    dSP ;

	    ENTER ;
	    SAVETMPS ;

	    PUSHMARK(SP);
	    PUSHs(SvRV(SV_stopper_ref));
	    PUSHs(sv_2mortal(newSVpv(term.data(), term.size())));
	    PUTBACK ;

	    int count = call_method("stop_word", G_SCALAR);

	    SPAGAIN ;

	    if (count != 1)
		croak("callback function should return 1 value, got %d", count);

	    // Breaks with SvTRUE(POPs) ?!?!?!
	    bool r = SvTRUE(SP[0]);
	    POPs ;

	    PUTBACK ;
	    FREETMPS ;
	    LEAVE ;

	    return r;
	}

    private:
	SV * SV_stopper_ref;
};

class perlMatchDecider : public Xapian::MatchDecider {
    SV *callback;

  public:
    perlMatchDecider(SV *func) {
	callback = newSVsv(func);
    }

    ~perlMatchDecider() {
	SvREFCNT_dec(callback);
    }

    bool operator()(const Xapian::Document &doc) const {
	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);

	SV *arg = sv_newmortal();

	Document *pdoc = new Document(doc);
	sv_setref_pv(arg, "Search::Xapian::Document", (void *)pdoc);
	XPUSHs(arg);

	PUTBACK;

	int count = call_sv(callback, G_SCALAR);

	SPAGAIN;
	if (count != 1)
	    croak("callback function should return 1 value, got %d", count);

	int decide_actual_result = POPi;

	PUTBACK;

	FREETMPS;
	LEAVE;

	return decide_actual_result;
    }
};

class perlExpandDecider : public Xapian::ExpandDecider {
    SV *callback;

  public:
    perlExpandDecider(SV *func) {
	callback = newSVsv(func);
    }

    ~perlExpandDecider() {
	SvREFCNT_dec(callback);
    }

    bool operator()(const string &term) const {
	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);

	XPUSHs(sv_2mortal(newSVpv(term.data(), term.size())));

	PUTBACK;

	int count = call_sv(callback, G_SCALAR);

	SPAGAIN;
	if (count != 1)
	    croak("callback function should return 1 value, got %d", count);

	int decide_actual_result = POPi;

	PUTBACK;

	FREETMPS;
	LEAVE;

	return decide_actual_result;
    }
};

/* PerlMatchSpy class
 *
 * Make operator(doc, wt) call Perl $OBJECT->register(doc, wt)
 */

class PerlMatchSpyAdaptor : public Xapian::MatchSpy {
    public:
        PerlMatchSpyAdaptor(SV* spy) {
            obj = newRV_inc(spy);
        }

        ~PerlMatchSpyAdaptor() {
            sv_2mortal(obj);
        }

        void operator()(const Xapian::Document& doc, Xapian::weight wt) {
            dSP ;

            ENTER ;
            SAVETMPS ;

            PUSHMARK(SP);

            SV* arg = sv_newmortal();
            Document* pdoc = new Document(doc);
            sv_setref_pv(arg, "Search::Xapian::Document", (void*) pdoc);
            
            PUSHs(SvRV(obj));
            XPUSHs(arg);
            mXPUSHn(wt);

            PUTBACK ;

            call_method("register", G_VOID);

            SPAGAIN ;
            FREETMPS ;
            LEAVE ;
        }

    private:
        SV * obj;
};

/* PerlSpyAwareEnquire
 *
 * Extend Xapian::Enquire to keep track of all created PerlMatchSpyAdatptor classes
 * Helps avoid cyclic references and memory leaks 
 */
class PerlSpyAwareEnquire : public Xapian::Enquire {
    public:
        PerlSpyAwareEnquire(Database& database) : Xapian::Enquire(database) {
        }

        ~PerlSpyAwareEnquire() {
            freePerlSpies();
        }

        void add_pmatchspy(SV* spy) {
            MatchSpy* iMatchSpy = new PerlMatchSpyAdaptor(spy);
            try {
                add_matchspy(iMatchSpy);
                perlSpyRefs.push_back(iMatchSpy);
            } catch (...) {
                delete iMatchSpy;
                throw;
            }   
        }

        void clear_matchspies() {
            Enquire::clear_matchspies();
            freePerlSpies();
        }
    private:
        std::vector<MatchSpy*> perlSpyRefs;

        void freePerlSpies() {
            while(!perlSpyRefs.empty()){
                delete perlSpyRefs.back();
                perlSpyRefs.pop_back();
            }
        }
}; 


MODULE = Search::Xapian		PACKAGE = Search::Xapian

PROTOTYPES: ENABLE

string
sortable_serialise(double value)

double
sortable_unserialise(string value)

const char *
version_string()

int
major_version()

int
minor_version()

int
revision()

INCLUDE: XS/BM25Weight.xs
INCLUDE: XS/BoolWeight.xs
INCLUDE: XS/Database.xs
INCLUDE: XS/Document.xs
INCLUDE: XS/Enquire.xs
INCLUDE: XS/MSet.xs
INCLUDE: XS/MSetIterator.xs
INCLUDE: XS/ESet.xs
INCLUDE: XS/Error.xs
INCLUDE: XS/ESetIterator.xs
INCLUDE: XS/RSet.xs
INCLUDE: XS/MultiValueSorter.xs
INCLUDE: XS/Query.xs
INCLUDE: XS/QueryParser.xs
INCLUDE: XS/SimpleStopper.xs
INCLUDE: XS/Stem.xs
INCLUDE: XS/Stopper.xs
INCLUDE: XS/TermGenerator.xs
INCLUDE: XS/TermIterator.xs
INCLUDE: XS/TradWeight.xs
INCLUDE: XS/PostingIterator.xs
INCLUDE: XS/PositionIterator.xs
INCLUDE: XS/ValueIterator.xs
INCLUDE: XS/WritableDatabase.xs
INCLUDE: XS/Weight.xs

INCLUDE: XS/DateValueRangeProcessor.xs
INCLUDE: XS/NumberValueRangeProcessor.xs
INCLUDE: XS/StringValueRangeProcessor.xs


INCLUDE: XS/MatchSpy.xs
INCLUDE: XS/ValueCountMatchSpy.xs

BOOT:
    {
	HV *mHvStash = gv_stashpv( "Search::Xapian", TRUE );
#define ENUM_CONST(P, C) newCONSTSUB( mHvStash, (char*)#P, newSViv(C) )

	ENUM_CONST(OP_AND, Query::OP_AND);
	ENUM_CONST(OP_OR, Query::OP_OR);
	ENUM_CONST(OP_AND_NOT, Query::OP_AND_NOT);
	ENUM_CONST(OP_XOR, Query::OP_XOR);
	ENUM_CONST(OP_AND_MAYBE, Query::OP_AND_MAYBE);
	ENUM_CONST(OP_FILTER, Query::OP_FILTER);
	ENUM_CONST(OP_NEAR, Query::OP_NEAR);
	ENUM_CONST(OP_PHRASE, Query::OP_PHRASE);
	ENUM_CONST(OP_VALUE_RANGE, Query::OP_VALUE_RANGE);
	ENUM_CONST(OP_SCALE_WEIGHT, Query::OP_SCALE_WEIGHT);
	ENUM_CONST(OP_ELITE_SET, Query::OP_ELITE_SET);
	ENUM_CONST(OP_VALUE_GE, Query::OP_VALUE_GE);
	ENUM_CONST(OP_VALUE_LE, Query::OP_VALUE_LE);

	ENUM_CONST(DB_OPEN, DB_OPEN);
	ENUM_CONST(DB_CREATE, DB_CREATE);
	ENUM_CONST(DB_CREATE_OR_OPEN, DB_CREATE_OR_OPEN);
	ENUM_CONST(DB_CREATE_OR_OVERWRITE, DB_CREATE_OR_OVERWRITE);

	ENUM_CONST(ENQ_DESCENDING, Enquire::DESCENDING);
	ENUM_CONST(ENQ_ASCENDING, Enquire::ASCENDING);
	ENUM_CONST(ENQ_DONT_CARE, Enquire::DONT_CARE);

	ENUM_CONST(FLAG_BOOLEAN, QueryParser::FLAG_BOOLEAN);
	ENUM_CONST(FLAG_PHRASE, QueryParser::FLAG_PHRASE);
	ENUM_CONST(FLAG_LOVEHATE, QueryParser::FLAG_LOVEHATE);
	ENUM_CONST(FLAG_BOOLEAN_ANY_CASE, QueryParser::FLAG_BOOLEAN_ANY_CASE);
	ENUM_CONST(FLAG_WILDCARD, QueryParser::FLAG_WILDCARD);
	ENUM_CONST(FLAG_PURE_NOT, QueryParser::FLAG_PURE_NOT);
	ENUM_CONST(FLAG_PARTIAL, QueryParser::FLAG_PARTIAL);
	ENUM_CONST(FLAG_SPELLING_CORRECTION, QueryParser::FLAG_SPELLING_CORRECTION);
	ENUM_CONST(FLAG_SYNONYM, QueryParser::FLAG_SYNONYM);
	ENUM_CONST(FLAG_AUTO_SYNONYMS, QueryParser::FLAG_AUTO_SYNONYMS);
	ENUM_CONST(FLAG_AUTO_MULTIWORD_SYNONYMS, QueryParser::FLAG_AUTO_SYNONYMS);
	ENUM_CONST(FLAG_DEFAULT, QueryParser::FLAG_DEFAULT);

	ENUM_CONST(STEM_NONE, QueryParser::STEM_NONE);
	ENUM_CONST(STEM_SOME, QueryParser::STEM_SOME);
	ENUM_CONST(STEM_ALL, QueryParser::STEM_ALL);

	ENUM_CONST(FLAG_SPELLING, TermGenerator::FLAG_SPELLING);
    }
