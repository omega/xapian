/* multimatch.h: class for performing a match
 *
 * ----START-LICENCE----
 * Copyright 1999,2000 BrightStation PLC
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
 * USA
 * -----END-LICENCE-----
 */

#ifndef OM_HGUARD_MULTIMATCH_H
#define OM_HGUARD_MULTIMATCH_H

#include "match.h"
#include "stats.h"
#include "refcnt.h"

#include "omqueryinternal.h"

#include <vector>
#include "autoptr.h"  // auto_ptr

class SingleMatch;

/** Class for performing a match over multiple SingleMatch objects.
 */
class MultiMatch
{
    private:
	/// Vector of the items
	std::vector<RefCntPtr<SingleMatch> > leaves;

	/// stats gatherer
	AutoPtr<StatsGatherer> gatherer;

	OmQueryInternal query_save_for_hack;
	OmSettings moptions_save_for_hack;

	/// Construct a SingleMatch object from an Database
	RefCntPtr<SingleMatch> make_match_from_database(Database *db);

	/** Prepare all the sub matchers.
	 *
	 *  This calls prepare_match() on all the sub matchers until they
	 *  all return true to signal that they are prepared.
	 */
	void prepare_matchers();

	/// Copying is not permitted.
	MultiMatch(const MultiMatch &);

	/// Assignment is not permitted.
	void operator=(const MultiMatch &);

	void set_query(const OmQueryInternal * query);
	void set_rset(const OmRSet & omrset);
	void set_options(const OmSettings & moptions);
    public:
	/** MultiMatch constructor.
	 *
	 *  @param db_       The database to use.
	 *
	 *  @param gatherer_ An auto_ptr to a StatsGatherer instance.
	 *                   The MultiMatch takes ownership of the
	 *                   StatsGatherer.  This argument is optional;
	 *                   the default is to use a LocalStatsGatherer,
	 *                   suitable for non-network use.
	 */
	MultiMatch(const OmDatabase &db_,
		   const OmQueryInternal * query,
		   const OmRSet & omrset,
		   const OmSettings & moptions,
		   AutoPtr<StatsGatherer> gatherer_
		       = AutoPtr<StatsGatherer>(new LocalStatsGatherer()));
	~MultiMatch();

	void get_mset(om_doccount first, om_doccount maxitems,
		      OmMSet & mset,
		      const OmMatchDecider *mdecider);
};

#endif /* OM_HGUARD_MULTIMATCH_H */
