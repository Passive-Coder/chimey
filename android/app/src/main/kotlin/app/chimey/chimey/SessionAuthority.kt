package app.chimey.chimey

import java.util.concurrent.CompletableFuture

/** A replaced capture worker may finish, but cannot publish into its successor. */
class SessionAuthority {
    class Lease(val id:Long) { val stopped=CompletableFuture<Unit>(); @Volatile var cancelled=false }
    private var sequence=0L
    @Volatile var current:Lease?=null; private set
    @Synchronized fun begin():Lease { current?.cancelled=true; return Lease(++sequence).also{current=it} }
    fun active(lease:Lease)=current===lease && !lease.cancelled
    @Synchronized fun cancel(lease:Lease) { lease.cancelled=true }
    @Synchronized fun runIfActive(lease:Lease, action:()->Unit):Boolean {
        if(!active(lease)) return false
        action(); return true
    }
    fun finish(lease:Lease) { lease.stopped.complete(Unit) }
}
